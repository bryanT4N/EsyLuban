using System.Collections;
using System.Collections.Generic;
using System.IO;
using UnityEngine;
// Comes from the com.code-philosophy.luban package (see Packages/manifest.json).
// Current versions put it under Luban.SimpleJSON; older ones used a bare
// SimpleJSON, which is what the generated code used to reference.
using Luban.SimpleJSON;

public class Main : MonoBehaviour
{
    // The player's language: a column name of the text table. Switching languages
    // in game means changing this and refreshing the text on screen.
    public string language = "zh";

    private dataTables.Tables _tables;

    // Start is called before the first frame update
    void Start()
    {
        _tables = new dataTables.Tables(LoadByteBuf);
        UnityEngine.Debug.LogFormat("item[1].name:{0}", _tables.TbItem[1].Name);

        // Text fields hold a key; the words live in the text table, one column per language.
        string key = _tables.TbL10NDemo[11].Text;
        UnityEngine.Debug.LogFormat("{0} ({1}): {2}", key, language, Text(key));
        language = "en";
        UnityEngine.Debug.LogFormat("{0} ({1}): {2}", key, language, Text(key));

        UnityEngine.Debug.Log("== load succ==");
    }

    private string Text(string key)
    {
        var row = _tables.TbText.GetOrDefault(key);
        if (row == null)
        {
            return key;
        }
        return language == "en" ? row.En : row.Zh;
    }

    // Tables passes the table's output name (e.g. "item_tbitem"); this appends
    // the extension and the directory that gen_all.bat writes the client data to.
    private static JSONNode LoadByteBuf(string file)
    {
        return JSON.Parse(File.ReadAllText(Application.dataPath + "/GenData/client/" + file + ".json", System.Text.Encoding.UTF8));
    }

    // Update is called once per frame
    void Update()
    {

    }
}
