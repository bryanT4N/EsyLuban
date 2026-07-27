// The namespace here must match "topModule" in Tools/Luban/luban.conf --
// that setting is what names the generated namespace. This example uses
// "dataTables"; upstream's own sample used "cfg", so a conf copied from
// elsewhere will not compile against these helpers until one of the two
// is brought in line with the other.
public static class ExternalTypeUtil
{
    public static UnityEngine.Vector2 NewVector2(dataTables.vec2 v)
    {
        return new UnityEngine.Vector2(v.X, v.Y);
    }

    public static UnityEngine.Vector3 NewVector3(dataTables.vec3 v)
    {
        return new UnityEngine.Vector3(v.X, v.Y, v.Z);
    }

    public static UnityEngine.Vector4 NewVector4(dataTables.vec4 v)
    {
        return new UnityEngine.Vector4(v.X, v.Y, v.Z, v.W);
    }
}
