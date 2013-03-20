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
 * value(9) = start
 * value(10) = end
 * value(11) = strand
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
#include <algorithm>

/* MySQL Connector/C++ specific headers */
#include <mysql.h>

using namespace std;
using namespace libconfig;


/* Global variables */
Xapian::TermGenerator indexer;
Xapian::TermGenerator syn_indexer;
Xapian::WritableDatabase db;
Xapian::WritableDatabase syn_db;
map<string, int>  species_list;
map<string, int>  paper_id;


MYSQL *connection,mysql;
MYSQL_RES *result;
MYSQL_ROW row;
int query_state;


static void
replaceChar(string &str, char old, char new_char){
  size_t loc = str.find_first_of(old);
  while(loc != string::npos){
   str[loc] = new_char;
   loc = str.find_first_of(old);
  }
}

string
uniquify(string q, string type){
    string unique = type + q;
    replaceChar(unique, ' ', '_');
    replaceChar(unique, '.', '_');
    replaceChar(unique, '(', '_');
    replaceChar(unique, ')', '_');
    replaceChar(unique, '-', '_');
    replaceChar(unique, ':', '_');
    replaceChar(unique, '/', '_');
    replaceChar(unique, '\\', '_');
    replaceChar(unique, '|', '_');
    replaceChar(unique, '[', '_');
    replaceChar(unique, ']', '_');
    replaceChar(unique, '<', '_');
    replaceChar(unique, '>', '_');
    return unique;
}

string
splitFields (string &fields, bool first = false){
  string ret;
  size_t quote = fields.find_first_of('"');
  while(quote != string::npos){
    fields = fields.substr(quote+1);

    quote = fields.find_first_of('"');
    string word;
    
    if(quote==string::npos){
      quote = fields.length();
    }
    
    if(quote>0){
      word = fields.substr(0, quote);
      if(fields[quote-1] == '\\'){
        quote--;
      }
    }else{
      quote = 0; 
    }
    
    fields = fields.substr(quote+1);
    ret += word + " ";

    if(first){
     return word; 
    }
    quote = fields.find_first_of('"');
  }
  if(ret.length()<1){
    return ret; 
  }else{
    return ret.substr(0, ret.length()-1);
  }
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
  if((((field_name.find("name") != string::npos) || (int(field_name.find("term")) == 0))         && 
      (field_name.find("molecular") == string::npos)    &&
      (field_name.find("other") == string::npos)    &&
      (field_name.find("middle") == string::npos)    &&
      (field_name.find("first") == string::npos))   || 
      (field_name.find("synonym") != string::npos)) {
    //add any field with the word name or synonym in it as a synonym. do not add molecular_name
    
    line = splitFields(line, true);
    indexer.index_text(line, 20); //index words separately

    if (line.length() > 2) {
      if(((doc.get_value(6).length() < 1)  || (int(field_name.find("standard_name")) == 0) || (int(field_name.find("public_name")) == 0)) && (field_name.find("other") == string::npos)){
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
    doc.add_value(3, Xapian::sortable_serialise(species_list[line]));
    doc.add_value(5, line);
    syn_doc.add_value(3, Xapian::sortable_serialise(species_list[line]));
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
        string unique = uniquify(obj_name, obj_class);
        indexer.index_text(unique);
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
          size_t tab = line.find_first_of('\t');
          if(tab==string::npos){
            getline(read,line);
            continue;
          }
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
    
    if(!read.is_open()){
     cout << "File " << filename << " does not exist." << endl;
     return; 
    }

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
  
    cout << "Begin compacting " << db_path << endl;
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
  cout << "Done compacting " << db_path << endl;
}


void
indexGFF3obj(MYSQL_ROW row, string species){
      
        string obj_class = "Gene";
        string obj_name = row[0];
        string start = row[1];
        string end = row[2];
        string strand = row[3];
        string alias;
        string search_desc;
        if(row[4]){
          alias = row[4];
          alias.erase(remove(alias.begin(), alias.end(), '\n'), alias.end());
          search_desc = search_desc + "title=<i>" + alias + "</i>\n";
        }

        
        //index the first line and set up the document
        Xapian::Document doc;
        Xapian::Document syn_doc;
        indexer.set_document(doc);
        
        string note;
        if(row[5]){
          note = row[5];
          note.erase(remove(note.begin(), note.end(), '\n'), note.end());
          indexer.index_text(note, 10);
          search_desc = search_desc + "remark=" + note + "\n";
        }
        
        string description;
        if(row[6]){
          description = row[6];
          indexer.index_text(description, 10);          
          description.erase(remove(description.begin(), description.end(), '\n'), description.end());
          search_desc = search_desc + "description=" + description + "\n";
        }

        doc.add_value(0, obj_class); // set value 0 to class
        doc.add_value(1, obj_name); // set value 1 to WBID
        syn_doc.add_value(0, obj_class); // set value 0 to class
        syn_doc.add_value(1, obj_name); // set value 1 to WBID
        doc.add_value(6, obj_name);
        syn_doc.add_value(6, obj_name);
        
        doc.add_value(9, start); 
        doc.add_value(10, end); 
        doc.add_value(11, strand); 

        syn_doc.add_value(9, start);
        syn_doc.add_value(10, end);
        syn_doc.add_value(11, strand); 
        
        obj_name = Xapian::Unicode::tolower(obj_name);
        obj_class = Xapian::Unicode::tolower(obj_class);
        doc.add_value(2, obj_class); // set value 2 to lowercase class
        syn_doc.add_value(2, obj_class); // set value 2 to lowercase class
        syn_doc.add_term(obj_name, 1);

        
        //add the class and wbid as terms
        indexer.index_text(obj_name, 500); //EXTRA EXTRA count on the wbid
        indexer.index_text(obj_class);
        string unique = uniquify(obj_name, obj_class);
        indexer.index_text(unique);

        replaceChar(obj_name, '-', '_');
        //add the class and wbid as terms
        indexer.index_text(obj_name, 500); //EXTRA EXTRA count on the wbid
        indexer.index_text(obj_class);
        indexer.index_text(obj_class + obj_name);
        
        doc.add_value(3, Xapian::sortable_serialise(species_list[species]));
        doc.add_value(5, species);
        syn_doc.add_value(3, Xapian::sortable_serialise(species_list[species]));
        syn_doc.add_value(5, species);
        indexer.index_text(species, 1);
        
        

        if (!alias.empty()) {        
          indexer.index_text(alias, 20);
          replaceChar(alias, '-', '_');
          if(alias.length() < 245){
            db.add_synonym(alias, obj_name);
            syn_doc.add_term(alias, 1);
          }
          indexer.index_text(alias, 40); //extra count on names
        }
        cout << obj_class << ": " << obj_name << "|" << alias << endl;
                cout << search_desc << endl;
                
                replaceChar(species, '_', '-');
                indexer.index_text(species, 10);

        doc.set_data(search_desc);
        db.add_document(doc);
        syn_db.add_document(syn_doc);
}


void
indexGFF3(string species){
    cout << "indexing gff3 species " << species << endl;
    
    //connect to database
    mysql_init(&mysql);
    connection = mysql_real_connect(&mysql,"localhost","wormbase","",'\0',0,0,0); //GET NONROOT USER!!
    if(connection==NULL)
    {
        cout<<mysql_error(&mysql)<<endl;
        return;
    }
    else
    {
              cout<<"\tconnected to mysql" <<endl;
    }
    string q = "SELECT SCHEMA_NAME FROM INFORMATION_SCHEMA.SCHEMATA WHERE SCHEMA_NAME = \'" + species + "\'";
    query_state = mysql_query(connection, q.c_str());
    result = mysql_store_result(connection);
    if ( mysql_fetch_row(result) == NULL ){
        cout << "\t" << species << " is not a database "  <<  endl;
        return;
    }
    
    connection = mysql_real_connect(&mysql,"localhost","wormbase","",species.c_str(),0,0,0); //GET NONROOT USER!!
    if(connection==NULL)
    {
        cout<<mysql_error(&mysql)<<endl;
        return;
    }
    else
    {
        cout<<"\tconnected to " << species <<endl;
    }
    
    //get query
    query_state = mysql_query(connection, "SET @alias = (SELECT id FROM attributelist al WHERE al.tag = 'Alias')");
    query_state = mysql_query(connection, "SET @note = (SELECT id FROM attributelist al WHERE al.tag = 'Note')");
    query_state = mysql_query(connection, "SET @parent = (SELECT id FROM attributelist al WHERE al.tag = 'parent_id')");
    query_state = mysql_query(connection, "SET @info = (SELECT id FROM attributelist al WHERE al.tag = 'info'); ");

    query_state = mysql_query(connection, "SELECT f.name, f.start, f.end, f.strand, a.attribute_value as alias, note.attribute_value as note, GROUP_CONCAT(d.attribute_value) as info, f.id FROM (SELECT f.id, f.start, f.end, f.strand, n.name FROM feature f, typelist t, name n WHERE f.typeid = t.id AND f.id = n.id AND t.tag = 'gene:WormBase') f LEFT JOIN attribute note ON f.id = note.id AND note.attribute_id = @note LEFT JOIN attribute a ON f.id = a.id AND note.attribute_id = @alias LEFT JOIN attribute child ON CONCAT('gene:', f.name) = child.attribute_value AND child.attribute_id = @parent LEFT JOIN attribute d ON child.id = d.id AND d.attribute_id = @info GROUP BY f.id, f.name, f.start, f.end, f.strand, alias, note");
    if (query_state !=0) {
      cout << mysql_error(connection) << endl;
      return;
    }
    
    //process query results
    result = mysql_store_result(connection);
    while ( ( row = mysql_fetch_row(result)) != NULL ) {
      indexGFF3obj(row, species);
    }
    
    //close mysql connection
    mysql_free_result(result);
    mysql_close(connection);
    cout << "\tdone indexing gff3 species " << species << endl;
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
    
        // Open the database for update, creating a new database if necessary.
    db = Xapian::WritableDatabase(db_path + "/main-full", Xapian::DB_CREATE_OR_OPEN);
    syn_db = Xapian::WritableDatabase(db_path + "/syn-full", Xapian::DB_CREATE_OR_OPEN);

    
    for(int i=0; i<species_settings.getLength(); i++){
      const Setting &spec = species_settings[i];
      string name;
      int id;
      int gff3;
      
      spec.lookupValue("name", name);
      spec.lookupValue("id", id);
      species_list[name] = id;
      
      if(spec.lookupValue("gff3", gff3) && (gff3 == 1)){
        indexGFF3(name);
      }

    }

    map<string, string(*)[5]>  classes;
    int desc_size;
    string desc[5];



  
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


      // Explicitly commit so that we get to see any errors.
      db.commit();
      syn_db.commit();

      if(setting.exists("after")){
        const char* after;
        setting.lookupValue("after", after);
        char* f = (char *) malloc(strlen(acedmp_path) + 10 + strlen(after));
        strcpy(f, acedmp_path);
        strcat(f, "/");
        strcat(f, after);
        indexLongText(f, root);
        free(f);
        // Explicitly commit so that we get to see any errors.
        db.commit();
        syn_db.commit();
      }
      cout << "Done indexing " << filename << endl;
      free(filename);
      
    }
    compactDB(db_path + "/main");
    compactDB(db_path + "/syn");  
    cout << "Done indexing AceDB" << endl;
} catch (const Xapian::Error &e) {
    cout << e.get_description() << endl;
    exit(1);
}
