export env LC_ALL=en_US.UTF-8

HOME=/home/tbui
EXPDIR=$PWD

SCRIPTS=${HOME}/mosesdecoder/scripts
DETRUECASER=${SCRIPTS}/recaser/detruecase.perl

src=ja
tgt=vi
GPUS=$1
MODEL_NAME=$2
MODEL=$PWD/models/${MODEL_NAME}/checkpoint_best.pt
BIN_DATA=$EXPDIR/data/tmp/bin-data
TAGGED_DATA=$EXPDIR/data/evaluation/tmp/tagged-data
########################## Validation dataset #########################################

CUDA_VISIBLE_DEVICES=$GPUS env LC_ALL=en_US.UTF-8 fairseq-generate $BIN_DATA \
            --input $TAGGED_DATA/valid.${src} \
            --path $MODEL \
            --task translation_multi_simple_epoch \
            --source_lang "${src}" \
            --target_lang "${tgt}" \
            --encoder-langtok "tgt" \
            --decoder-langtok \
            --lang-pairs "${src}-${tgt}" \
            --beam 5 | tee ${PWD}/results/${MODEL_NAME}/${src}2${tgt}/valid_trans_result.${tgt}
# --constraints ordered \
            # --prefix-size "<${tgt}>" \
grep ^H ${PWD}/results/${MODEL_NAME}/${src}2${tgt}/valid_trans_result.${tgt} | cut -f3 > ${PWD}/results/${MODEL_NAME}/${src}2${tgt}/valid_trans.${tgt}
cat ${PWD}/results/${MODEL_NAME}/${src}2${tgt}/valid_trans.${tgt} | sed -r 's/(@@ )|(@@ ?$)//g' > ${PWD}/results/${MODEL_NAME}/${src}2${tgt}/valid_rmvbpe.${tgt}

# detruecase
$DETRUECASER < ${PWD}/results/${MODEL_NAME}/${src}2${tgt}/valid_rmvbpe.${tgt} > ${PWD}/results/${MODEL_NAME}/${src}2${tgt}/valid_detruecase.${tgt}

# detokenize
python3.6 $PWD/postprocess/detokenize.py ${PWD}/results/${MODEL_NAME}/${src}2${tgt}/valid_detruecase.${tgt} ${PWD}/results/${MODEL_NAME}/${src}2${tgt}/valid.${tgt}
python3.6 $PWD/preprocess/normalize.py ${PWD}/results/${MODEL_NAME}/${src}2${tgt}/valid.${tgt} ${PWD}/results/${MODEL_NAME}/${src}2${tgt}/valid_normalize.${tgt}
echo "VALID" >> ${PWD}/results/${MODEL_NAME}/${src}2${tgt}/valid_result.txt
perl $PWD/multi-bleu.pl $PWD/data/evaluation/tmp/normalized/valid.${tgt} < ${PWD}/results/${MODEL_NAME}/${src}2${tgt}/valid_normalize.${tgt} >> ${PWD}/results/${MODEL_NAME}/${src}2${tgt}/valid_result.txt

########################## Test dataset #########################################

CUDA_VISIBLE_DEVICES=$GPUS env LC_ALL=en_US.UTF-8 fairseq-generate $BIN_DATA \
            --input $TAGGED_DATA/test.${src} \
            --path $MODEL \
            --task translation_multi_simple_epoch \
            --source_lang "${src}" \
            --target_lang "${tgt}" \
            --encoder-langtok "tgt" \
            --decoder-langtok \
            --lang-pairs "${src}-${tgt}" \
            --beam 5 | tee ${PWD}/results/${MODEL_NAME}/${src}2${tgt}/test_trans_result.${tgt}

grep ^H ${PWD}/results/${MODEL_NAME}/${src}2${tgt}/test_trans_result.${tgt} | cut -f3 > ${PWD}/results/${MODEL_NAME}/${src}2${tgt}/test_trans.${tgt}
cat ${PWD}/results/${MODEL_NAME}/${src}2${tgt}/test_trans.${tgt} | sed -r 's/(@@ )|(@@ ?$)//g' > ${PWD}/results/${MODEL_NAME}/${src}2${tgt}/test_rmvbpe.${tgt}

# detruecase
$DETRUECASER < ${PWD}/results/${MODEL_NAME}/${src}2${tgt}/test_rmvbpe.${tgt} > ${PWD}/results/${MODEL_NAME}/${src}2${tgt}/test_detruecase.${tgt}

# detokenize
python3.6 $PWD/postprocess/detokenize.py ${PWD}/results/${MODEL_NAME}/${src}2${tgt}/test_detruecase.${tgt} ${PWD}/results/${MODEL_NAME}/${src}2${tgt}/test.${tgt}
python3.6 $PWD/preprocess/normalize.py ${PWD}/results/${MODEL_NAME}/${src}2${tgt}/test.${tgt} ${PWD}/results/${MODEL_NAME}/${src}2${tgt}/test_normalize.${tgt}
echo "test" >> ${PWD}/results/${MODEL_NAME}/${src}2${tgt}/test_result.txt
perl $PWD/multi-bleu.pl $PWD/data/evaluation/tmp/normalized/test.${tgt} < ${PWD}/results/${MODEL_NAME}/${src}2${tgt}/test_normalize.${tgt} >> ${PWD}/results/${MODEL_NAME}/${src}2${tgt}/test_result.txt