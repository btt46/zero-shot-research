import ctranslate2
import argparse

def get_batch(file):
    res = []
    with open(file, 'r') as fp:
        lines = fp.readlines()
        fp.close()
    for line in lines:
        res.append(line.split(' '))
    return res

def main(args):
    # Get input
    model_input = get_batch(args.input_file)
    
    # Initialize model
    translator = ctranslate2.Translator(args.model_path, device="cpu")

    results = translator.translate_batch(
        model_input,
        target_prefix=[[args.stok] for i in range(len(model_input))],
    )

    with open(args.output_file, 'w') as fp:
        for line in results:
            print(' '.join(line))
            fp.write(' '.join(line))

if __name__=='__main__':
    parser =  argparse.ArgumentParser()
    parser.add_argument('--input_file', '-i', dest='input_file',)
    parser.add_argument('--model_path','-m',dest='model_path')
    parser.add_argument('--special_token','-stok',dest='stok')
    parser.add_argument('--output_file', '-o', dest='output_file')

    args = parser.parse_args()
    main(args)
