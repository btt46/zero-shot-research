import ctranslate2
import argparse



def main(args):
    # Initialize model
    converter = ctranslate2.converters.FairseqConverter(
        model_path=args.model_path,              # Path to the Fairseq model (.pt file).
        data_dir=args.data_dir,                # Path to the Fairseq data directory.
    )

    converter.convert(   
         output_dir=args.output_dir,          # Path to the output directory.
    )

if __name__=='__main__':
    parser =  argparse.ArgumentParser()
    parser.add_argument('--model_path','-m',dest='model_path')
    parser.add_argument('--data_dir','-d', dest='data_dir')
    parser.add_argument('--source_lang','-slang', dest='slang')
    parser.add_argument('--target_lang','-tlang', dest='tlang')
    parser.add_argument('--output_dir', '-o', dest='output_dir')

    args = parser.parse_args()
    main(args)
