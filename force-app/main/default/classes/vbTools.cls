//
//  Contains static utility classes
//  Author : Vincent Brenet, vbrenet@salesforce.com
//  May 10, 2017 : initialization
//
//    added comment in scratch org
//
public class vbTools {

//  
//  convert a person account field name beginning by PC_ to a field ApiName
//  
    public static String convertPersonAccountField (String fieldName) {
        if (!fieldName.startsWith('PC_'))
            return fieldName;
        String result = fieldName.substringAfter('_'); // remove leading 'PC_'
        result = result.toLowerCase().capitalize();
        while (result.contains('_')) {
            String left = result.substringBefore('_').capitalize();
            String right = result.substringAfter('_').capitalize();
            result = left+right;
        }
        return result;
    }
//
// generic method : does +1 in a <String / Integer> map if the key is found, else creates an entry in the map with 1 as the value
//
    public static void incrementStringMap(Map<String, integer> theMap, String s) {
        if (theMap.containsKey(s)) 
            theMap.put(s, theMap.get(s)+1);
        else
            theMap.put(s, 1);
    }
//
// generic method : output a **sorted** <String / Integer> map as a String, with an optional title
//
    public static String outputStringMap (String title, Map<String, integer> theMap) {
    // one more comment
        String outputedMap = title;
        if (outputedMap == null) outputedMap = '\n';
        List<String> sortedKeys = new List<String>();
        for (String key : theMap.keyset())
            sortedKeys.add(key);
        sortedKeys.sort();
        for (String k : sortedKeys)
            outputedMap += k + ' : ' + theMap.get(k) + '\n';
        return outputedMap;
    }
}