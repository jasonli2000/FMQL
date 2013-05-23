#!/usr/bin/env python

#
# LICENSE:
# This program is free software; you can redistribute it and/or modify it 
# under the terms of the GNU Affero General Public License version 3 (AGPL) 
# as published by the Free Software Foundation.
# (c) 2010-2013 caregraf
#

import re
from collections import defaultdict

class DescribeTypeResult(object):

    """
    TODO: 
    - may rename "FileInfo" (ala "FieldInfo")
    - the easy access provided here will inform improvements to the raw FMQL JSON scheduled for V1.1.
    - handle "corrupt" file and "corrupt" field info properly for easy reports
    
    A simple facade for easy access to an FMQL Describe Type result, a peer of FMQLDescribeResult. To FMQL's exposure of FileMan's Native Schema, it highlights:
    - list multiple: multiples with only one field - these 'sub files' represent simple lists of items
    - does a field "own" its name ie/ is it the first user of a name. Remember that 
    - set of codes: some are just booleans (Y or Y/N). These are distinguished from "proper" sets of codes.
    
    Fixes FMQL quirks:
    - file id returned in . form in Schema but Data uses _ form. _ form used here
    - lot's of "detail" stuffed into one 'detail' field. Expanded in FieldInfo
    """ 
    def __init__(self, describeTypeResult):
        self.__result = describeTypeResult
        
    def __str__(self):
        mu = "File: " + self.name + " (" + self.id + ")\n"
        mu += "Count (FileMan): " + self.count + "\n" if self.count else ""
        if self.location:
            mu += "Location: " + self.location + "\n"
            mu += "Array: " + self.array + "\n"
        mu += "Parent: " + self.parent + "\n" if self.parent else ""
        mu += "Description: " + self.description + "\n" if self.description else ""
        if self.isListMultiple:
            mu += "List Multiple\n"
            mu += "\tpredicate name: " + self.listMultiplePredicateName + "\n"
            mu += "\ttype: " + self.fieldInfos()[0].type + "\n"
            return mu
        # The following won't apply to list multiples
        mu += "Files referenced (not including multiples and theirs): " + str(len(self.references())) + "\n"
        fieldInfos = self.fieldInfos()
        mu += "Number of fields: " + str(len(fieldInfos)) + "\n"
        mu += "Number of indexed fields: " + str(len([fieldInfo for fieldInfo in fieldInfos if fieldInfo.index])) + "\n"
        fieldInfosByType = defaultdict(list)
        for fieldInfo in fieldInfos:
            # Want to distinguish boolean and non boolean enum
            ftype = fieldInfo.type
            if ftype == FieldInfo.FIELDTYPES["3"] and fieldInfo.isBooleanCoded:
                ftype = "SET OF CODES [BOOLEAN]"
            fieldInfosByType[ftype].append(fieldInfo)
        for i, fieldType in enumerate(fieldInfosByType, 1):
            no = len(fieldInfosByType[fieldType])
            mu += "Number of " + fieldType + ": " + str(no) + " (" + str((no*100)/len(fieldInfos)) + "%) " + "\n"
        mu += "** Duplicates one or more field names **\n" if self.hasDuplicatedFieldNames else ""
        return mu
           
    @property
    def id(self):
        return re.sub(r'\.', '_', self.__result["number"])
           
    @property
    def name(self):
        return self.__result["name"].title()
        
    @property
    def description(self):
        return self.__result["description"]["value"] if "description" in self.__result else ""
        
    @property
    def count(self):
        return self.__result["count"] if "count" in self.__result else ""
        
    @property
    def applicationGroups(self):
        return self.__result["applicationGroups"] if "applicationGroups" in self.__result else ""
        
    @property
    def lastIEN(self):
        return self.__result["lastIEN"] if "lastIEN" in self.__result else ""
    
    @property        
    def location(self):
        if "location" in self.__result:
            return self.__result["location"]
        return ""
        
    @property
    def array(self):
        """
        Base array ie DPT or ... Way to gather files that all share an array!
        """
        if not self.location:
            return ""
        return re.match(r'\^([^\(]+)', self.location).group(1)
       
    @property
    def parent(self):
        # Test if multiple this way too
        if "parent" in self.__result:
            return re.sub(r'\.', '_', self.__result["parent"]) 
        return ""
            
    @property
    def isListMultiple(self):
        """
        TODO: FMQL - embed number of fields in the FieldInfo of a multiple field. That way, can know if it is a list multiple.
        """
        if not self.parent:
            return False
        if len(self.fieldInfos()) == 1:
            return True
        return False
        
    @property
    def listMultiplePredicateName(self):
        """
        If something is a list multiple then make its predicate name from its only field.
        """
        if not self.isListMultiple:
            return ""
        return self.fieldInfos()[0].predicateName
        
    @property
    def isBlankNodeMultiple(self):
        raise Exception("Not yet implemented - may do from inputTransform if any")
        
    def multiples(self):
        return [fieldInfo.multipleId for fieldInfo in self.fieldInfos() if fieldInfo.type == "MULTIPLE"]
        
    def references(self):
        return set(range for fieldInfo in self.fieldInfos() if fieldInfo.type in ["POINTER TO A FILE", "VARIABLE-POINTER"] for range in fieldInfo.ranges())
                
    def fieldInfos(self): # only non corrupt
        """
        Iterator of field information - returns tuples that describe each field
        """
        try:
            return self.__fieldInfos
        except:
            pass
        self.__fieldInfos = []
        namesSoFar = set()
        for fieldResult in self.__result["fields"]:
            if "corruption" in fieldResult: # corruption (may be a name, maybe not)
                continue
            self.__fieldInfos.append(FieldInfo(self.id, fieldResult, fieldResult["name"] not in namesSoFar))
            namesSoFar.add(fieldResult["name"])
        return self.__fieldInfos
        
    @property
    def hasDuplicatedFieldNames(self):
        """
        REM: FileMan only enforces uniqueness for field ids, not for field names.
        """
        for fieldInfo in self.fieldInfos():
            if not fieldInfo.isNameOwner:
                return True
        return False
        
    def corruptFields(self):
        pass
                    
class FieldInfo(object):

    # TMP Til FMQL uses .8. ie/ I FLDFLAGS["D" S FLDTYPE=1 ; Date 
    # will look into file .81/^DI(.81,"C","D")
    FIELDTYPES = {
        "1": "DATE-TIME",
        "2": "NUMERIC",
        "3": "SET OF CODES",
        "4": "FREE TEXT",
        "5": "WORD-PROCESSING",
        "6": "COMPUTED", # issue of BC, Cm, DC in details
        "7": "POINTER TO A FILE",
        "8": "VARIABLE-POINTER",
        "9": "MULTIPLE",
        "10": "MUMPS"
    }

    # a name owner is the FIRST field in the file to use a name. All others don't 'own' the name
    def __init__(self, fileId, describeFieldResult, isNameOwner):
        self.__fileId = fileId
        self.__result = describeFieldResult   
        self.__isNameOwner = isNameOwner
                
    @property
    def id(self):
        """
        Unlike for file, leaving . form for id of field
        """
        return self.__result["number"]
        
    @property
    def fileId(self):
        return self.__fileId
        
    @property
    def name(self):  
        # Note: only container would know if ambiguous
        return self.__result["name"].title()
        
    @property
    def isNameOwner(self):
        """
        Owner is the first (order by id) user of a name in a file
        """
        return self.__isNameOwner
        
    @property
    def predicateName(self):
        """
        Predicate name is unique in the file, lowercase normalized (for RDF etc) and in the context of the file (ie/ not unique across all files so must suffix with fileId)
        
        Note: could walk all files and see if unique across all files BUT problem that a new definition could change everything. Better to air on side of "in file context" caution.
        
        TODO: currently this is an instance method as need all the meta to decide if a name is ambiguous. Once FMQL notes ambiguity on the server side, then this method becomes much simpler and should be a class method like normalizeFieldName.
        """
        if self.isNameOwner:
            return FieldInfo.normalizeFieldName(self.__result["name"]) + "-" + self.fileId
        # Not owner so must add the fieldId as well as the fileId to the name!
        return FieldInfo.normalizeFieldName(self.__result["name"]) + "-" + re.sub(r'\.', '_', self.id) + "-" + self.fileId
        
    @staticmethod
    def normalizeFieldName(fieldName):
        """
        Static to allow the same normalization to be used without creating the full fieldInfo 
        ex/ Utility doesn't like ":" in a field name ex/ ROUTINES (RN1:RN2) -> ROUTINES (RN1-RN2)
        ex/ ALIAS FMP/SSN ... don't want / in a URL'ed id
        """
        return re.sub("[&@\'\/]", "__", re.sub(":", "-", re.sub(r' ', '_', fieldName))).lower()

    @property
    def description(self):
        return self.__result["description"]["value"] if "description" in self.__result else ""
    
    @property 
    def type(self):
        return self.FIELDTYPES[self.__result["type"]]
        
    @property
    def flags(self):
        """
        TODO: replace with proper breakout ALA Rambler/Schema Browser
        """
        return self.__result["flags"]
                
    @property
    def location(self):
        if "location" in self.__result:
            return self.__result["location"]
        return ""

    @property
    def index(self):
        return self.__result["index"] if "index" in self.__result else ""
        
    @property
    def inputTransform(self):
        return self.__result["inputTransform"] if "inputTransform" in self.__result else ""

    @property
    def computation(self):
        return self.__result["computation"] if "computation" in self.__result else ""

    @property
    def multipleId(self):
        return re.sub(r'\.', '_', self.__result["details"]) if self.__result["type"] == "9" else ""  

    def ranges(self):
        """
        TODO: FMQL - should record NAME of file pointed to as well as its id
        """
        if self.__result["type"] not in ["7", "8"]:
            return []
        if self.__result["type"] == "7":
            return [re.sub(r'\.', '_', self.__result["details"])]
        # 8 VARIABLE POINTER         
        return [re.sub(r'\.', '_', vrFileId) for vrFileId in self.__result["details"].split(";")]
        
    def codes(self):
        """
        Singleton coded values (bound only): len(codes) == 1
        """
        if self.__result["type"] != "3":
            return []
        codes = []
        for enumValue in self.__result["details"].split(";"):
            if not enumValue:
                continue
            if re.search(r':', enumValue):
                enumMN = enumValue.split(":")[0]
                enumLabel = enumValue.split(":")[1]
            else:
                # TBD: FMQL TODO - RPMS "BORDERLINE" has no :
                enumMN = enumValue
                enumLabel = enumValue  
            codes.append((enumMN, enumLabel))  
        return codes
            
    @property
    def isBooleanCoded(self):
        """
        Many coded fields amount to booleans. Better to represent them that way than as mini terminologies. ie/ distinguish boolean coded values from first class, larger cousins.
        
        Two variations: 1 value (ie/ bound or not) and 2 value (Y/N). Not all 2 value are boolean. They may be of form, "XorY" with values of X or Y. This can't be a boolean unless it is renamed "isX" or "X".
        """
        codes = self.codes()
        if not len(codes):
            return False
        if len(codes) == 1 and self.__codeValueBooleanCompatible(codes[0]):
            return True
        if len(codes) == 2 and sum(1 for code in codes if self.__codeValueBooleanCompatible(code)):
            return True
        return False
           
    """
    Notes on singleton boolean:
    TODO: more specials or leave for singletons ie/ CODEs vs ...
    - 8.19 WITHOLD DISPLAY OF TIMING TEXT (u'1', u'WITHHOLD DISPLAY OF TIMING TEXT')
    - 4 TYPE (u'D', u'DEPARTURE STATUS')
	- 4.03 PROVIDERS INTERVENTION CODE (u'M0', u'PRESCRIBER CONSULTED')
	- 5.07 PHARMACIST INTERVENTION CODE (u'R0', u'PHARMACIST CONSULTED')
	- 28 AVAILABLE (u'1', u'NOT AVAILABLE')
    """  
    def __codeValueBooleanCompatible(self, codeValue):
        # mn is Y/N
        if codeValue[0] in ["Y", "N"]:
            return True
        # label is Y or N (sometimes MN is 1 or 0)
        if codeValue[1] in ["Y", "YES", "N", "NO"]:
            return True
        # field name ends in FLAG or INDICATOR
        if re.search(r'[FLAG|INDICATOR]$', self.name, re.IGNORECASE):
            return True
        # SPECIAL CASE EXCLUDE: Individual/Group Policy in 2.
        if re.search(r'\/', self.name):
            return False
        # If escaped label is contained in the field name (typical is INACTIVE)
        # Escaped and past participle-less form - used to check if label of enum is embedded in a field name
        ppfl = re.escape(codeValue[1]) if not re.search(r'ED$', codeValue[1]) else codeValue[1][-1]
        if re.search(ppfl, self.name, re.IGNORECASE):
            return True
        return False    

# ############################# Test Driver ####################################

import sys
import urllib
import urllib2
import json

# FMQLEP = "http://www.examplehospital.com/fmqlEP"
FMQLEP = "http://livevista.caregraf.info/fmqlEP"     

def main():

    queryURL = FMQLEP + "?" + urllib.urlencode({"fmql": "DESCRIBE TYPE 2"}) 
    reply = json.loads(urllib2.urlopen(queryURL).read())
    dtr = DescribeTypeResult(reply)
    print dtr

if __name__ == "__main__":
    main()