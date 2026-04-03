
============================================
Fields Mapping
============================================
=> In code editor's type ahead, propose Product2 fields. Use the syntax field_<API name of the field> when persist in CMLSnippet. Manage reverse translation CMLSnippet to code editor
=> When creating the CML and parsing a CMLSnippet: if we find a field_<APIName of field>:
- linked to class, add field to all the types that derive from this class. use string or decimal or int
- linked to product2, add field to type associated to that produc2
- immediately after a relation mapped to a PCG, add field to all the types in the child PRCs
- immediately after a relation mapped to a PRC, add field to the type linked to the PRC's producty


============================================
Variables / Expressions
============================================
- 


============================================
Annotations in PCG
============================================
- 

============================================
headers
============================================
- when parsing CML snippets that have no attach point, add these at the top of the CML