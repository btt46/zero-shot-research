import argparse


def merge_file(input_files, output_file):
    contents = []
    for file in input_files:
        with open(file,'r') as fp:
           lines = fp.readlines()
           contents.append(lines)
        fp.close()
    
    count_non=0
    with open(output_file, 'w') as fp:
        while True:
            for i in range(len(input_files)):
                if len(contents[i]) > 0 :
                    fp.write(contents[i][0])
                    contents[i].pop(0)
                else:
                    count_non +=1
                    if count_non == len(input_files):
                        return
            
        fp.close()


if __name__=="__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument('-i','--input_files', nargs='+', help='Input files' ,dest='i',required=True)
    parser.add_argument('-o','--output_files', type=str, help='Output file', dest='o',required=True)
    args = parser.parse_args()

    merge_file(args.i, args.o) 
