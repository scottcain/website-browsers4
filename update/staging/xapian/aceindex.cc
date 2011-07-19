/** @file aceindex.cc
 * @brief Index each entry of an acedb dump as a Xapian document.
 */
/* This is a simple indexer for acedb dumps
 * based on simpleindex.cc
 *
 * does not prefix any terms
 *
 * value(0) = object class
 * value(1) = WormBase unique identifier (WBid)
 * value(2) = object class (all lowercase)
 * value(3) = species (in sortable number)
 * value(4) = publication date
 * value(5) = species (text)
 * value(6) = paper type
 * 
 * all tags are added as terms, unless it is a 'not_' tag
 * all 'name' or 'synonym' tags are added as synonyms to the WBid
 *
 * author:
 * Abigail Cabunoc
 * abigail.cabunoc@oicr.on.ca
 */

#include <xapian.h>

#include <iostream>
#include <string>
#include <cstdlib> // For exit().
#include <cstring>


using namespace std;


static void
replaceChar(string &str, char old, char new_char){
  size_t loc = str.find_first_of(old);
  while(loc != string::npos){
   str[loc] = new_char;
   loc = str.find_first_of(old);
  }
}

string
splitFields (string &fields, bool first = false){
  string ret;
  size_t quote = fields.find_first_of('"');
  while(quote != string::npos){
    fields = fields.substr(quote+1);
    
    quote = fields.find_first_of('"');
    string word = fields.substr(0, quote);
    if(fields[quote-1] == '\\'){
      quote--;
    }
    fields = fields.substr(quote+1);
    
    ret += word + " ";
    if(first){
     return word; 
    }
    quote = fields.find_first_of('"');
  }
  return ret.substr(0, ret.length()-1);
}

string
parseSpecies (string &species) {
 string ret;
 ret.push_back(species[0]);
 size_t space = species.find_first_of(' ') + 1;
 ret += "_" + species.substr(space, species.length()-space);
 return ret;
}

int
main(int argc, char **argv)
try {
    if (argc != 2 || argv[1][0] == '-') {
      cout << "Usage: " << argv[0] << " PATH_TO_DATABASE" << endl;
      exit(1);
    }
    
    
    // TODO: make a config file or something, this probably shouldn't be hardcoded
    map<string, int>  species;
    species["c_elegans"] = 6239;
    species["c_angaria"] = 96668;
    species["c_brenneri"] = 135651;
    species["c_briggsae"] = 6238;
    species["c_japonica"] = 281687;
    species["c_remanei"] = 31234;
    species["p_pacificus"] = 54126;
    species["a_sum"] = 6253;
    species["b_malayi"] = 6279;
    species["c_drosophilae"] = 96641;
    species["g_pallida"] = 36090;
    species["h_bacteriophora"] = 37862;
    species["h_contortus"] = 6289;
    species["m_hapla"] = 6305;
    species["m_incognita"] = 6306;
    species["n_brasiliensis"] = 36090;
    species["o_volvulus"] = 6282;
    species["s_ransomi"] = 554534;
    species["s_ratti"] = 34506;
    species["t_circumcincta"] = 45464;
    species["t_muris"] = 70415;
    species["t_spiralis"] = 6334;
    
    string paper_types [24] = {
      "Journal_article",
      "Review",
      "Comment",
      "News",
      "Letter",
      "Editorial",
      "Congresses",
      "Historical_article",
      "Biography",
      "Interview",
      "Lectures",
      "Interactive_tutorial",
      "Retracted_publication",
      "Technical_report",
      "Directory",
      "Monograph",
      "Published_erratum",
      "Meeting_abstract",
      "Gazette_article",
      "Book_chapter",
      "Book",
      "Email",
      "WormBook",
      "Other"
    };


    string db_path = argv[1];

    // Open the database for update, creating a new database if necessary.
    Xapian::WritableDatabase db(db_path + "/main", Xapian::DB_CREATE_OR_OPEN);
    Xapian::WritableDatabase syn_db(db_path + "/syn", Xapian::DB_CREATE_OR_OPEN);
    Xapian::TermGenerator indexer;
    Xapian::TermGenerator syn_indexer;
    
    string line;
    getline(cin, line);
    
    while (!cin.eof()) {
      if(!line.empty()){
        
      //index the first line and set up the document
        Xapian::Document doc;
        Xapian::Document syn_doc;
        indexer.set_document(doc);
        
        //get the class, the wbid
        string obj_class = line.substr(0, line.find_first_of(":")-1);
        string obj_name = splitFields(line);

        doc.add_value(0, obj_class); // set value 0 to class
        doc.add_value(1, obj_name); // set value 1 to WBID
        syn_doc.add_value(0, obj_class); // set value 0 to class
        syn_doc.add_value(1, obj_name); // set value 1 to WBID
        
        obj_name = Xapian::Unicode::tolower(obj_name);
        obj_class = Xapian::Unicode::tolower(obj_class);
        doc.add_value(2, obj_class); // set value 2 to lowercase class
        syn_doc.add_value(2, obj_class); // set value 2 to lowercase class
        syn_doc.add_term(obj_name, 1);
        
        //add the class and wbid as terms
        indexer.index_text(obj_name, 500); //EXTRA EXTRA count on the wbid
        indexer.index_text(obj_class);
        cout << obj_class << ": " << obj_name;

        //index the rest of the lines in the object
        getline(cin, line);
        while(!line.empty()) {
          string copy = line;
          line = Xapian::Unicode::tolower(line);
          string field_name = line.substr(0, line.find_first_of('\t'));

          if(((field_name.find("name") != string::npos)         && 
              (field_name.find("molecular") == string::npos)    &&
              (field_name.find("middle") == string::npos)    &&
              (field_name.find("first") == string::npos))   || 
             (field_name.find("synonym") != string::npos)) {
            //add any field with the word name or synonym in it as a synonym. do not add molecular_name
            
            line = splitFields(line, true);
            indexer.index_text(line, 20); //index words separately

            if (line.length() > 2) {
              if((doc.get_data().length() < 1)  || (int(field_name.find("standard_name")) == 0) ){
                string text = splitFields(copy, true);
                syn_doc.set_data(text);
                doc.set_data(text);
              }              
              replaceChar(line, '-', '_');
              cout << "|" << line;
              db.add_synonym(line, obj_name);
              syn_doc.add_term(line, 1);
              indexer.index_text(line, 40); //extra count on names
            }
          }else if(int(field_name.find("species")) == 0){ //add species if found
            line = splitFields(line, true);
            indexer.index_text(line, 1);
            line = parseSpecies(line);
            doc.add_value(3, Xapian::sortable_serialise(species[line]));
            doc.add_value(5, line);
            syn_doc.add_value(3, Xapian::sortable_serialise(species[line]));
            syn_doc.add_value(5, line);
            indexer.index_text(line, 1);
          }else if(int(field_name.find("publication_date")) == 0){ //mostly for paper, add publication date as value
            line = splitFields(line, true);
            doc.add_value(4, line);
            indexer.index_text(line, 1);
          }else if(int(field_name.find("brief_citation")) == 0){ //for paper, hack for short citation
            size_t begin = copy.find_first_of('"');
            string text = copy.substr(begin + 1, copy.find_first_of(')') - begin);
            syn_doc.set_data(text);
            doc.set_data(text);
            indexer.index_text(splitFields(line, true), 1);
          }else if((int(field_name.find("not_")) != 0) && (field_name.find("_not_") == string::npos)){
            if(int(obj_class.find("paper")) == 0){
              for(int i=0; i<24; i++){
                string paper_type = paper_types[i];
                if(int(field_name.find(paper_type)) == 0){
                    doc.add_value(6, paper_type);
                    syn_doc.add_value(6, paper_type);
                    break;
                }
              }
            }
            
            // do not add objects with a NOT tag
            indexer.index_text(splitFields(line), 1); //lower count index
          }
          getline(cin, line);
        }
        cout << endl;
        db.add_document(doc);
        syn_db.add_document(syn_doc);
      }
      getline(cin,line);
    }

    // Explicitly commit so that we get to see any errors.
    db.commit();
    syn_db.commit();
} catch (const Xapian::Error &e) {
    cout << e.get_description() << endl;
    exit(1);
}
