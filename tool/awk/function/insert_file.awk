function insert_file (file)
{
    if (v > 4)
        print "Reading \""file"\" for "FILENAME"..." >> "/dev/stderr"
    gsub(/~\//,HOME"/",file)
    if (system("[ -s \""file"\" ]") == 1) {
        if (v > 2)
            print "No such include for "FILENAME" named \""file"\"" >> "/dev/stderr"
        exit 4
    }
    if (file in sources) {
        if (v > 2)
            print "Recursion from "FILENAME" into already loaded "file >> "/dev/stderr"
        exit 3
    }
    sources[file]=1
    while (getline line < file)
        print line
    close(file)
    if (v > 5)
        print "Closed \""file"\"" >> "/dev/stderr"
}
