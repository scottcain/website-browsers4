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
 * value(6) = readable label
 * value(7) = paper type
 * value(8) = paper type id (for search, sortable number)
 * 
 * all tags are added as terms, unless it is a 'not_' tag
 * all 'name' or 'synonym' tags are added as synonyms to the WBid
 *
 * author:
 * Abigail Cabunoc
 * abigail.cabunoc@oicr.on.ca
 */

#include <xapian.h>
#include <libconfig.h++>
#include <sys/stat.h>
#include <sys/types.h>

#include <iostream>
#include <fstream>
#include <string>
#include <cstdlib> // For exit().
#include <stdio.h>
#include <cstring>
#include <dirent.h>



using namespace std;
using namespace libconfig;


/* Global variables */
Xapian::TermGenerator indexer;
Xapian::TermGenerator syn_indexer;
Xapian::WritableDatabase db;
Xapian::WritableDatabase syn_db;
map<string, int>  species;
map<string, int>  paper_id;

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


bool 
indexLineBegin(string field_name, string line, string copy, string obj_name, Xapian::Document doc, Xapian::Document syn_doc){
  if((((field_name.find("name") != string::npos) || (field_name.find("term") != string::npos))         && 
      (field_name.find("molecular") == string::npos)    &&
      (field_name.find("middle") == string::npos)    &&
      (field_name.find("first") == string::npos))   || 
      (field_name.find("synonym") != string::npos)) {
    //add any field with the word name or synonym in it as a synonym. do not add molecular_name
    
    line = splitFields(line, true);
    indexer.index_text(line, 20); //index words separately

    if (line.length() > 2) {
      if((doc.get_value(6).length() < 1)  || (int(field_name.find("standard_name")) == 0) || (int(field_name.find("public_name")) == 0)){
        string text = splitFields(copy, true);
        doc.add_value(6, text);
        syn_doc.add_value(6, text);
      }              
      replaceChar(line, '-', '_');
      if(line.length() < 245){
        cout << "|" << line;
        db.add_synonym(line, obj_name);
        syn_doc.add_term(line, 1);
      }
      indexer.index_text(line, 40); //extra count on names
    }
    return true;
  }else if(int(field_name.find("species")) == 0){ //add species if found
    line = splitFields(line, true);
    indexer.index_text(line, 1);
    line = parseSpecies(line);
    doc.add_value(3, Xapian::sortable_serialise(species[line]));
    doc.add_value(5, line);
    syn_doc.add_value(3, Xapian::sortable_serialise(species[line]));
    syn_doc.add_value(5, line);
    indexer.index_text(line, 1);
    return true;
  }
  return false;
}


string 
indexLineEnd(string field_name, string line, string copy, string obj_name, Xapian::Document doc, Xapian::Document syn_doc, string desc[], int desc_size){
  string ret;
  if((int(field_name.find("not_")) != 0) && (field_name.find("_not_") == string::npos)){
    
    //add blurbs to data
    for(int j=0; j<desc_size; j++){
      string d = desc[j];
      bool first = true;
      if((field_name.find("author")) == 0){ first = false; }
      
      if(field_name.find(d) != string::npos){
        ret = ret + field_name + "=" + splitFields(copy, first) + "\n";
        continue;
      }else if((int(field_name.find("address")) == 0) && (line.find("institution") != string::npos)){ 
        ret = ret + "institution=" + splitFields(copy, true) + "\n";
        continue;
      }
    }

    // do not add objects with a NOT tag
    indexer.index_text(splitFields(line), 1); //lower count index
  }
  return ret;
}


bool
indexLinePaper(string field_name, string line, string copy, string obj_name, Xapian::Document doc, Xapian::Document syn_doc, string desc[], int desc_size, string paper_types[]){
  string ret;
  if(int(field_name.find("publication_date")) == 0){ //mostly for paper, add publication date as value
    line = splitFields(line, true);
    doc.add_value(4, line);
    indexer.index_text(line, 1);
    return true;
  }else if(int(field_name.find("brief_citation")) == 0){ //for paper, hack for short citation
    size_t begin = copy.find_first_of('"');
    string text = copy.substr(begin + 1, copy.find_first_of(')') - begin);
    doc.add_value(6, text);
    syn_doc.add_value(6, text);
    indexer.index_text(splitFields(line, true), 1);
    return true;
  }else if((int(field_name.find("not_")) != 0) && (field_name.find("_not_") == string::npos)){
    for(int i=0; i<24; i++){
      string paper_type = paper_types[i];
      if(int(field_name.find(paper_type)) == 0){
          doc.add_value(7, paper_type);
          syn_doc.add_value(7, paper_type);
          doc.add_value(8, Xapian::sortable_serialise(i));
          syn_doc.add_value(8, Xapian::sortable_serialise(i));
          return true;
      }
    }
  }
  return false;
}





void
indexFile(char* filename, string desc[], int desc_size, Setting &root){
  
    string paper_types [24];
    string f_name = filename;
    bool paper = (f_name.find("Paper") != string::npos);

    if(paper){
      const Setting &paper_settings = root["paper_types"];

      for(int i=0; i<paper_settings.getLength(); i++){
        string paper_type = paper_settings[i];
        paper_types[i] = paper_type;
      }
    }
  
    ifstream read;
    read.open(filename);
    
    if(!read.is_open()){
     cout << "File " << filename << " does not exist." << endl;
     return; 
    }
    
    string line;
    getline(read, line);
    while (!read.eof()) {

      if(!line.empty()){
        //get the class, the wbid
        string obj_class = line.substr(0, line.find_first_of(":")-1);
        string obj_name = splitFields(line);


        //index the first line and set up the document
        Xapian::Document doc;
        Xapian::Document syn_doc;
        indexer.set_document(doc);

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
        indexer.index_text(obj_class + obj_name);
        cout << obj_class << ": " << obj_name;
        
        
        string search_desc;

        //index the rest of the lines in the object
        getline(read, line);
        
        
        //THIS IS A HACK
        bool do_not_index = false;
        if(line.find("WBProcess") != string::npos){
          do_not_index = true;
        }
        
        while(!line.empty()) {
          string copy = line;
          line = Xapian::Unicode::tolower(line);
          string field_name = line.substr(0, line.find_first_of('\t'));

          bool done = indexLineBegin(field_name, line, copy, obj_name, doc, syn_doc);
          
          if(!done && paper){
              done = indexLinePaper(field_name, line, copy, obj_name, doc, syn_doc, desc, desc_size, paper_types);
          } 
          if(!done){
            search_desc = search_desc + indexLineEnd(field_name, line, copy, obj_name, doc, syn_doc, desc, desc_size);
          }
          
          getline(read, line);
        }
        cout << endl;
        
        if(paper){
          int c = db.get_lastdocid() + 1;
          paper_id[obj_name] = c;
        }
        if(!do_not_index){ //HACK
//           cout << search_desc << endl;
          doc.set_data(search_desc);
          db.add_document(doc);
          syn_db.add_document(syn_doc);
        }
      }
      

      getline(read,line);
    }
}


void
indexLongText(char* filename, Setting &root){

    ifstream read;
    read.open(filename);
    
    string line;
    getline(read, line);

    while (!read.eof()) {

      if(!line.empty()){

        string obj_name = splitFields(line);

        int did = -1;
        obj_name = Xapian::Unicode::tolower(obj_name);
        if(paper_id.find(obj_name) != paper_id.end()){
          did = paper_id[obj_name];
          paper_id.erase(obj_name);
        }

        getline(read, line);
        string abstract;
        while(int(line.find("***LongTextEnd***")) != 0) {
          if(line != "")
            abstract = abstract + "abstract=" + line + "\n";
          getline(read, line);
        }        
        
        if(did > -1){
          cout << obj_name << "|" << did << endl;

          Xapian::Document doc = db.get_document(did);
          indexer.set_document(doc);
          indexer.index_text(abstract);
          doc.set_data(doc.get_data() + abstract);
          db.replace_document(did, doc);
        }
        

        getline(read, line);

      }
      getline(read,line);
    }
    while (!paper_id.empty()){
      paper_id.erase(paper_id.begin());
    }
}

void 
compactDB(string db_path){
  
    Xapian::Compactor compact;
    compact.add_source(db_path + "-full");
    compact.set_destdir(db_path);
    
    compact.set_renumber(false);
    compact.set_compaction_level(Xapian::Compactor::FULLER);
    compact.compact();
    
    DIR *pDIR;
    struct dirent *entry;
    string pth = db_path + "-full";
    if( pDIR=opendir(pth.c_str()) ){
        while(entry = readdir(pDIR)){
              if( strcmp(entry->d_name, ".") != 0 && strcmp(entry->d_name, "..") != 0 ){
                string fpth = pth + "/" + entry->d_name;
                remove(fpth.c_str());
              }
        }
        remove(pth.c_str());
        closedir(pDIR);
    }
  
}


int
main(int argc, char **argv)
try {
    if (argc != 3 || argv[1][0] == '-') {
      cout << "Usage: " << argv[0] << argc << " CONFIG_FILE WSXXX" << endl;
      exit(1);
    }

    Config cfg;
    cfg.readFile(argv[1]);
    Setting &root = cfg.getRoot();
    const Setting &species_settings = root["species"];
    const Setting &classes_settings = root["classes"];
    
    const char* acedmp_path; 
    root.lookupValue("acedump", acedmp_path);
    
    string db_path;
    root.lookupValue("search", db_path);
    
    db_path = db_path + "/" + argv[2] + "/search";
    char * cstr = new char [db_path.size()+1];
    strcpy (cstr, db_path.c_str());
    mkdir(cstr, S_IRWXU | S_IRWXG | S_IROTH | S_IXOTH);
    cout << db_path << endl;
    
    for(int i=0; i<species_settings.getLength(); i++){
      const Setting &spec = species_settings[i];
      string name;
      int id;
      
      spec.lookupValue("name", name);
      spec.lookupValue("id", id);
      species[name] = id;
    }

    map<string, string(*)[5]>  classes;
    int desc_size;
    string desc[5];


    // Open the database for update, creating a new database if necessary.
    db = Xapian::WritableDatabase(db_path + "/main-full", Xapian::DB_CREATE_OR_OPEN);
    syn_db = Xapian::WritableDatabase(db_path + "/syn-full", Xapian::DB_CREATE_OR_OPEN);

  
    for(int j=0; j < classes_settings.getLength() ; j++) {
      Setting &setting = classes_settings[j];
      const char* f_name; 
      setting.lookupValue("filename", f_name);
      
      char* filename = (char *) malloc(strlen(acedmp_path) + 10 + strlen(f_name));
      strcpy(filename, acedmp_path);
      strcat(filename, "/");
      strcat(filename, f_name);

      if(! setting.exists("desc")){
        desc_size = 5;
        desc[0] = "description";
        desc[1] = "definition";
        desc[2] = "remark";
        desc[3] = "summary";
        desc[4] = "title";
      }else{
        const Setting &c_settings = setting["desc"];
        desc_size = c_settings.getLength();
        
        for(int i=0; i<desc_size; i++){
          string d = c_settings[i];
          desc[i] = d;
        }
      }
      cout << "Indexing " << filename << endl;
      indexFile(filename, desc, desc_size, root);
      free(filename);

      // Explicitly commit so that we get to see any errors.
      db.commit();
      syn_db.commit();
      
      if(setting.exists("after")){
        const char* after;
        setting.lookupValue("after", after);
        char* filename = (char *) malloc(strlen(acedmp_path) + 10 + strlen(after));
        strcpy(filename, acedmp_path);
        strcat(filename, "/");
        strcat(filename, after);
        indexLongText(filename, root);
        free(filename);
        // Explicitly commit so that we get to see any errors.
        db.commit();
        syn_db.commit();
      }
      cout << "Done indexing " << filename << endl;
      
    }
    compactDB(db_path + "/main");
    compactDB(db_path + "/syn");  
    
} catch (const Xapian::Error &e) {
    cout << e.get_description() << endl;
    exit(1);
}
