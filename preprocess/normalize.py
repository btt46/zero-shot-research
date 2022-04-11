import sys
import unicodedata

def nfkc_normalize(input_file, output_file):
    # Read file
    with open(input_file, 'r', encoding="utf-8") as fp:
        lines = fp.readlines()
        fp.close()

    # Normalizing
    new_lines = []
    for line in lines:
        line = unicodedata.normalize('NFKD', line)
        new_lines.append(line)

    with open(output_file, 'w', encoding='utf-8') as fp:
        fp.writelines(new_lines)
        fp.close()

if __name__=='__main__':
    nfkc_normalize(sys.argv[1], sys.argv[2])
    