export env LC_ALL=en_US.UTF-8

HOME=/home/tbui
EXPDIR=$PWD

SCRIPTS=${HOME}/mosesdecoder/scripts
DETRUECASER=${SCRIPTS}/recaser/detruecase.perl

INPUT_FILE=$1
FOLDER=$2
TAG=$3

cat $INPUT_FILE | sed -r 's/(@@ )|(@@ ?$)//g | <vi>' > $FOLDER/rmvbpe.txt

# detruecase
$DETRUECASER < $FOLDER/rmvbpe.txt > $FOLDER/detruecase.txt

# detokenize
python3.6 $PWD/postprocess/detokenize.py $FOLDER/detruecase.txt $FOLDER/detok.txt
python3.6 $PWD/preprocess/normalize.py $FOLDER/detok.txt $FOLDER/output.txt