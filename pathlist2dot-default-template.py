schema = \
{
    'template':
        "digraph metadata { "
#        "\t\nrankdir=LR;"
"\t\nfontcolor=grey;fontsize=20;"
        "\t\nscale=0.5;"
        "\t\nnode[fontsize=9,height=0.1,width=0.1,style=filled,fontcolor=black,fillcolor=white];"
        "\t\nbgcolor=black;"
        "\t\n%s"
        "}",
    'STYLE_NODE': 'shape=Mrecord,fillcolor="#eeeeec"',
    'STYLE_COMMON_NODE': 'shape=plaintext,fillcolor="#babdb6"',
#    'STYLE_ARRAY_NODE': 'fillcolor="#fce94f",shape=tab',
    'STYLE_ARRAY_NODE': 'style=solid,fontcolor="#fce94f",color="#fce94f",shape=plaintext',
    'STYLE_DIR_NODE': 'fillcolor="#3465a4",shape=folder',
    'STYLE_FILE_NODE': 'fillcolor="#73d216",shape=tab',
    'STYLE_LEAF_NODE': 'fillcolor="#729fcf",shape=note',
}

