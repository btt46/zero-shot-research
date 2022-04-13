import argparse


def merge_file(input_files, output_file):
    contents = []
    for file in input_files:
        with open(file,'r') as fp:
           lines = fp.readlines()
           contents.append(lines)
        fp.close()
    
    print(len(contents[0]))
    print(len(contents[1]))
    print(len(contents[2]))
    print(len(contents[3]))
    with open(output_file, 'w') as fp:
        while len(contents) > 0:  
            for i in range(len(contents)):
                if len(contents[i]) > 0 :
                    fp.write(contents[i][0])
                    contents[i].pop(0)
                else:
                    contents.pop(i)
        print(len(contents))   
        fp.close()


if __name__=="__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('-i','--input_files', nargs='+', help='Input files' ,dest='i',required=True)
    parser.add_argument('-o','--output_files', type=str, help='Output file', dest='o',required=True)
    args = parser.parse_args()

    merge_file(args.i, args.o) 
