function resolve_file_content(ref)
{
    fdir=FILENAME
    sub(/[^/]+$/, "", fdir)
    gsub(/~\//,HOME"/",ref)
    status = ( RESOLVE_NAME " \"" ref "\" \"" FILENAME "\"" | getline file )
    close_status = close(RESOLVE_NAME " \"" ref "\" \"" FILENAME "\"")
    #cmd = "bash -c " shell_quote(RESOLVE_NAME " " ref " " FILENAME)
    #status = (cmd | getline file)
    #close_status = close(cmd)
    if (ret < 0) {
      print "getline error:" ERRNO > "/dev/stderr"
      exit 1
    }
    if (close_status !=0) {
      print "resolve failed, status", close_status >> "/dev/stderr"
      exit 1
    }
    if (system("[ -s \""file"\" ]") == 1) {
        if (v > 2)
            print "No such include for "FILENAME" include "ref" named \""file"\"" >> "/dev/stderr"
        exit 4
    }
    if (file in sources) {
        if (v > 2)
            print "Recursion from "FILENAME" into already loaded "file >> "/dev/stderr"
        exit 3
    }
    if (v > 4)
        print "Reading \""file"\" for "FILENAME"..." >> "/dev/stderr"
    sources[file]=1
    system(RESOLVE" \"" ref "\" \"" file "\" \"" FILENAME "\"")
    if (v > 5)
        print "Resolved \""file"\"" >> "/dev/stderr"
}
