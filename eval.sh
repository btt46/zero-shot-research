HOME=/home/tbui
EXPDIR=$PWD

SCRIPTS=${HOME}/mosesdecoder/scripts
DETRUECASER=${SCRIPTS}/recaser/detruecase.perl

src=$1
tgt=$2
GPUS=$3
MODEL_NAME=$4
MODEL=$PWD/models/${MODEL_NAME}/checkpoint_best.pt

