export env LC_ALL=en_US.UTF-8

HOME=/home/tbui
EXPDIR=$PWD

SCRIPTS=${HOME}/mosesdecoder/scripts
DETRUECASER=${SCRIPTS}/recaser/detruecase.perl

src=$1
tgt=$2
GPUS=$3
MODEL_NAME=$4
MODEL=$PWD/models/${MODEL_NAME}/checkpoint_best.pt
BIN_DATA=$EXPDIR/data/tmp/bin-data
TAGGED_DATA=$EXPDIR/data/evaluation/tmp/tagged-data
########################## Validation dataset #########################################

CUDA_VISIBLE_DEVICES=$GPUS env LC_ALL=en_US.UTF-8 fairseq-interactive $BIN_DATA \
            --input $TAGGED_DATA/valid.${src} \
            --path $MODEL \
            --beam 5 | tee ${PWD}/results/${src}2${tgt}/valid_trans_result.${tgt}

grep ^H ${PWD}/results/${src}2${tgt}/valid_trans_result.${tgt} | cut -f3 > ${PWD}/results/${src}2${tgt}/valid_trans.${tgt}
cat ${PWD}/results/${src}2${tgt}/valid_trans.${tgt} | sed -r 's/(@@ )|(@@ ?$)//g' > ${PWD}/results/${src}2${tgt}/valid_rmvbpe.${tgt}

# detruecase
$DETRUECASER < ${PWD}/results/${src}2${tgt}/valid_rmvbpe.${tgt} > ${PWD}/results/${src}2${tgt}/valid_detruecase.${tgt}

# detokenize
python3.6 $PWD/postprocess/detokenize.py ${PWD}/results/${src}2${tgt}/valid_detruecase.${tgt} ${PWD}/results/${src}2${tgt}/valid.${tgt}
python3.6 $PWD/preprocess/normalize.py ${PWD}/results/${src}2${tgt}/valid.${tgt} ${PWD}/results/${src}2${tgt}/valid_normalize.${tgt}
echo "VALID" >> ${PWD}/results/${src}2${tgt}/valid_result.txt
perl $PWD/multi-bleu.pl $PWD/data/tmp/normalized/valid.${tgt} < ${PWD}/results/${src}2${tgt}/valid_normalize.${tgt} >> ${PWD}/results/${MODEL_NAME}/valid_result.txt

########################## Test dataset #########################################

CUDA_VISIBLE_DEVICES=$GPUS env LC_ALL=en_US.UTF-8 fairseq-interactive $BIN_DATA \
            --input $TAGGED_DATA/test.${src} \
            --path $MODEL \
            --beam 5 | tee ${PWD}/results/${src}2${tgt}/test_trans_result.${tgt}

grep ^H ${PWD}/results/${src}2${tgt}/test_trans_result.${tgt} | cut -f3 > ${PWD}/results/${src}2${tgt}/test_trans.${tgt}
cat ${PWD}/results/${src}2${tgt}/test_trans.${tgt} | sed -r 's/(@@ )|(@@ ?$)//g' > ${PWD}/results/${src}2${tgt}/test_rmvbpe.${tgt}

# detruecase
$DETRUECASER < ${PWD}/results/${src}2${tgt}/test_rmvbpe.${tgt} > ${PWD}/results/${src}2${tgt}/test_detruecase.${tgt}

# detokenize
python3.6 $PWD/postprocess/detokenize.py ${PWD}/results/${src}2${tgt}/test_detruecase.${tgt} ${PWD}/results/${src}2${tgt}/test.${tgt}
python3.6 $PWD/preprocess/normalize.py ${PWD}/results/${src}2${tgt}/test.${tgt} ${PWD}/results/${src}2${tgt}/test_normalize.${tgt}
echo "test" >> ${PWD}/results/${src}2${tgt}/test_result.txt
perl $PWD/multi-bleu.pl $PWD/data/tmp/normalized/test.${tgt} < ${PWD}/results/${src}2${tgt}/test_normalize.${tgt} >> ${PWD}/results/${MODEL_NAME}/valid_result.txt