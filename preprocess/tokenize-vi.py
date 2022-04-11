from pyvi import ViTokenizer
import sys

def tokenizer(input_filename, output_filename):
	with open(input_filename,'r',encoding='utf-8') as f:
		lines = f.readlines()
		f.close()

	output_lines = []

	for line in lines:
		line = ViTokenizer.tokenize(line)
		output_lines.append(line)

	with open(output_filename, 'w',encoding='utf-8') as f:
		f.writelines(output_lines)
		f.close()

if __name__=='__main__':
	tokenizer(sys.argv[1], sys.argv[2])