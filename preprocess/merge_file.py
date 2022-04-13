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
    max_len = max([len(contents[i]) for i in range(len(contents))])
    
    with open(output_file, 'w') as fp:
        for i in range(max_len):
            for j in range(len(contents)):
                if i < len(contents[j]):
                    fp.write(contents[j][i])
        
        fp.close()


if __name__=="__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('-i','--input_files', nargs='+', help='Input files' ,dest='i',required=True)
    parser.add_argument('-o','--output_files', type=str, help='Output file', dest='o',required=True)
    args = parser.parse_args()

    merge_file(args.i, args.o) 
