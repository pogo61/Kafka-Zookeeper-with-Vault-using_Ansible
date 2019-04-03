import sys
import fileinput

def replaceAll(file,searchExp,replaceExp):

    print('file being changed is: '+str(file))
    print('expression being changed is: '+str(searchExp))
    print('expression to be changed to is: '+str(replaceExp))

    # read in all the lines for prelim check
    tempfile = open(file, 'r')
    lines = tempfile.readlines()
    tempfile.close()

    found = False

    # process the lines that need amending
    for line in lines:
        if str(searchExp) in line:
            print('about to change initial expression')
            for line in fileinput.input(file, inplace=True):
                print(line.rstrip().replace(searchExp, replaceExp))
            found = True

    # process the lines that need adding
    # firstly make sure that the line hasn't been changed before
    # if it has then change the search criteria and overwrite it
    # if it hasn't then insert a new line
    if not found:
        for line in lines:
            try:
                print('line is: '+line)
                print('modified search is: '+str(searchExp.rsplit(None, 1)[-1]))
                # if this  has been changed before then overwrite it
                if str(searchExp.rsplit(None, 1)[-1]) in line:
                    print('about to change old expression')
                    searchExp = str(line.rsplit(None, 1)[0])+' '+str(searchExp.rsplit(None, 1)[-1])
                    print('new searchExp is: '+searchExp)
                    for l in fileinput.input(file, inplace=True):
                        print(l.rstrip().replace(searchExp, replaceExp))
                    found = True
            except Exception as e:
                found = True
                print(str(e))

        # only insert totally new lines
        if not found:
            print('about to insert expression')
            ectHosts = open(file, 'a')
            ectHosts.write(str(replaceExp)+"\n")
            ectHosts.close()

if __name__ == "__main__":
    print("This is the name of the script: ", sys.argv[0])
    print("Number of arguments: ", len(sys.argv))
    print("The arguments are: " , str(sys.argv))
    replaceAll(sys.argv[1],sys.argv[2],sys.argv[3])