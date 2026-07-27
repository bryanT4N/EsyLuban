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
    // Start is called before the first frame update
    void Start()
    {
        var tables = new dataTables.Tables(LoadByteBuf);
        UnityEngine.Debug.LogFormat("item[1].name:{0}", tables.TbItem[1].Name);


        UnityEngine.Debug.Log("== load succ==");
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
