export env LC_ALL=en_US.UTF-8

HOME=/home/tbui
EXPDIR=$PWD

SCRIPTS=${HOME}/mosesdecoder/scripts
TOKENIZER=$SCRIPTS/tokenizer/tokenizer.perl
CLEAN=$SCRIPTS/training/clean-corpus-n.perl
TRUECASER_TRAIN=$SCRIPTS/recaser/train-truecaser.perl
TRUECASER=$SCRIPTS/recaser/truecase.perl
BPE_TOKENS=12000

DATASET=$PWD/data
DATASET_NAME="train valid test"
NORMALIZED_DATA=$DATASET/tmp/normalized
TOKENIZED_DATA=$DATASET/tmp/tok
TRUECASED_DATA=$DATASET/tmp/truecased
BPE_DATA=$DATASET/tmp/bpe-data
BIN_DATA=$DATASET/tmp/bin-data
TAGGED_DATA=$DATASET/tmp/tagged-data

# Making directories
if [ ! -d $DATASET/tmp ]; then
    mkdir -p $DATASET/tmp
fi

if [ ! -d $NORMALIZED_DATA ]; then
    mkdir -p $NORMALIZED_DATA
fi

if [ ! -d $TOKENIZED_DATA ]; then
    mkdir -p $TOKENIZED_DATA
fi

if [ ! -d $TRUECASED_DATA ]; then
    mkdir -p $TRUECASED_DATA
fi

if [ ! -d $BPE_DATA ]; then
    mkdir -p $BPE_DATA
fi

if [ ! -d $BIN_DATA ]; then
    mkdir -p $BIN_DATA
fi

if [ ! -d $TAGGED_DATA ]; then
    mkdir -p $TAGGED_DATA
fi

# Normalization
echo '=> Normalizing...'
for set in $DATASET_NAME; do
    python3.6 ${EXPDIR}/preprocess/normalize.py ${DATASET}/en-vi.data/${set}.en \
                                                ${NORMALIZED_DATA}/${set}.en-vi.en
    python3.6 ${EXPDIR}/preprocess/normalize.py ${DATASET}/en-vi.data/${set}.vi \
                                                ${NORMALIZED_DATA}/${set}.en-vi.vi
    python3.6 ${EXPDIR}/preprocess/normalize.py ${DATASET}/en-ja.data/${set}.en \
                                                ${NORMALIZED_DATA}/${set}.en-ja.en
    python3.6 ${EXPDIR}/preprocess/normalize.py ${DATASET}/en-ja.data/${set}.ja \
                                                ${NORMALIZED_DATA}/${set}.en-ja.ja
    # python3.6 ${EXPDIR}/preprocess/normalize.py ${DATASET}/ja-vi.data/${set}.ja \
    #                                             ${NORMALIZED_DATA}/${set}.ja-vi.ja   
    # python3.6 ${EXPDIR}/preprocess/normalize.py ${DATASET}/ja-vi.data/${set}.vi \
    #                                             ${NORMALIZED_DATA}/${set}.ja-vi.vi                                           
    
done


# Tokenization
echo "=> Tokenizing..."
for set in $DATASET_NAME; do
    $TOKENIZER -l en < ${NORMALIZED_DATA}/${set}.en-vi.en > ${TOKENIZED_DATA}/${set}.en-vi.en
    $TOKENIZER -l en < ${NORMALIZED_DATA}/${set}.en-ja.en > ${TOKENIZED_DATA}/${set}.en-ja.en
    python3.6 ${EXPDIR}/preprocess/tokenize-vi.py ${NORMALIZED_DATA}/${set}.en-vi.vi ${TOKENIZED_DATA}/${set}.en-vi.vi
    # python3.6 ${EXPDIR}/preprocess/tokenize-vi.py ${NORMALIZED_DATA}/${set}.ja-vi.vi ${TOKENIZED_DATA}/${set}.ja-vi.vi
done

cat ${TOKENIZED_DATA}/${set}.en-vi.en ${TOKENIZED_DATA}/${set}.en-ja.en > ${TOKENIZED_DATA}/train.corpus.en

# Truecaser
echo "=> Truecasing..."
echo "Training for English..."
$TRUECASER_TRAIN --model $DATASET/tmp/truecase.model.en --corpus ${TOKENIZED_DATA}/train.corpus.en

echo "Training for Vietnamese"
# cat ${TOKENIZED_DATA}/train.en-vi.vi ${TOKENIZED_DATA}/train.ja-vi.vi > ${TOKENIZED_DATA}/train.corpus.vi
cat ${TOKENIZED_DATA}/train.en-vi.vi  > ${TOKENIZED_DATA}/train.corpus.vi
$TRUECASER_TRAIN --model $DATASET/tmp/truecase.model.vi --corpus ${TOKENIZED_DATA}/train.corpus.vi

for set in $DATASET_NAME; do
    $TRUECASER --model $DATASET/tmp/truecase.model.en < ${TOKENIZED_DATA}/${set}.en-vi.en > ${TRUECASED_DATA}/${set}.en-vi.en
    $TRUECASER --model $DATASET/tmp/truecase.model.en < ${TOKENIZED_DATA}/${set}.en-ja.en > ${TRUECASED_DATA}/${set}.en-ja.en
    $TRUECASER --model $DATASET/tmp/truecase.model.vi < ${TOKENIZED_DATA}/${set}.en-vi.vi > ${TRUECASED_DATA}/${set}.en-vi.vi
    # $TRUECASER --model $DATASET/tmp/truecase.model.vi < ${TOKENIZED_DATA}/${set}.ja-vi.vi > ${TRUECASED_DATA}/${set}.ja-vi.vi
    mecab -Owakati ${NORMALIZED_DATA}/${set}.en-ja.ja > ${TRUECASED_DATA}/${set}.en-ja.ja 
    # mecab -Owakati ${NORMALIZED_DATA}/${set}.ja-vi.ja > ${TRUECASED_DATA}/${set}.ja-vi.ja 
done

for set in $DATASET_NAME; do
    cat ${TRUECASED_DATA}/${set}.en-vi.en ${TRUECASED_DATA}/${set}.en-vi.vi ${TRUECASED_DATA}/${set}.en-ja.en ${TRUECASED_DATA}/${set}.en-ja.ja   > ${TRUECASED_DATA}/${set}.src
    cat ${TRUECASED_DATA}/${set}.en-vi.vi ${TRUECASED_DATA}/${set}.en-vi.en ${TRUECASED_DATA}/${set}.en-ja.ja ${TRUECASED_DATA}/${set}.en-ja.en  > ${TRUECASED_DATA}/${set}.tgt
done

# learn bpe model with training data
subword-nmt learn-bpe -s ${BPE_TOKENS} < ${TRUECASED_DATA}/train.src > $DATASET/tmp/bpe.${BPE_TOKENS}.model

for set in $DATASET_NAME; do
    for lang in src; do
        subword-nmt apply-bpe -c $DATASET/tmp/bpe.${BPE_TOKENS}.model < ${TRUECASED_DATA}/${set}.${lang} > $BPE_DATA/${set}.bpe.${lang}
    done
done

for lang in src; do
    cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=1 && NR <=133317 {print  $0}' > $BPE_DATA/train.bpe.en-vi.en
    cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=133318 && NR <=266634 {print   $0}' > $BPE_DATA/train.bpe.en-vi.vi
    cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=266635 && NR <=489742 {print  $0}' > $BPE_DATA/train.bpe.en-ja.en
    cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=489743 && NR <=712850 {print  $0}' > $BPE_DATA/train.bpe.en-ja.ja
   
    ## validation
    cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=1 && NR <=1553 {print  $0}' > $BPE_DATA/valid.bpe.en-vi.en
    cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=1554 && NR <=3106 {print  $0}' > $BPE_DATA/valid.bpe.en-vi.vi
    cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=3107 && NR <=3977 {print  $0}' > $BPE_DATA/valid.bpe.en-ja.en
    cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=3978 && NR <=4848 {print  $0}' > $BPE_DATA/valid.bpe.en-ja.ja

    ## test
    cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=1 && NR <=1268 {print  $0}' > $BPE_DATA/test.bpe.en-vi.en
    cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=1269 && NR <=2536 {print  $0}' > $BPE_DATA/test.bpe.en-vi.vi
    cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=2537 && NR <=3730 {print  $0}' > $BPE_DATA/test.bpe.en-ja.en
    cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=3731 && NR <=4924 {print  $0}' > $BPE_DATA/test.bpe.en-ja.ja
done

fairseq-preprocess -s en -t vi \
			--destdir $BIN_DATA \
			--trainpref $BPE_DATA/train.bpe.en-vi \
			--validpref $BPE_DATA/valid.bpe.en-vi \
			--testpref $BPE_DATA/test.bpe.en-vi \
            --joined-dictionary  \
			--workers 10 \
            2>&1 | tee $EXPDIR/logs/preprocess_en-vi

fairseq-preprocess -s vi -t en \
			--destdir $BIN_DATA \
			--trainpref $BPE_DATA/train.bpe.en-vi \
			--validpref $BPE_DATA/valid.bpe.en-vi \
			--testpref $BPE_DATA/test.bpe.en-vi \
            --joined-dictionary --tgtdict $BIN_DATA/dict.en.txt \
			--workers 10 \
            2>&1 | tee $EXPDIR/logs/preprocess_vi-en

fairseq-preprocess -s en -t ja \
			--destdir $BIN_DATA \
			--trainpref $BPE_DATA/train.bpe.en-ja \
			--validpref $BPE_DATA/valid.bpe.en-ja \
			--testpref $BPE_DATA/test.bpe.en-ja \
            --joined-dictionary --tgtdict $BIN_DATA/dict.en.txt \
			--workers 10 \
            2>&1 | tee $EXPDIR/logs/preprocess_en-ja

fairseq-preprocess -s ja -t en \
			--destdir $BIN_DATA \
			--trainpref $BPE_DATA/train.bpe.en-ja \
			--validpref $BPE_DATA/valid.bpe.en-ja \
			--testpref $BPE_DATA/test.bpe.en-ja \
            --joined-dictionary --tgtdict $BIN_DATA/dict.en.txt \
			--workers 10 \
            2>&1 | tee $EXPDIR/logs/preprocess_ja-en



        


# adding tags
## train data
####################################################################################################################################
#### Model1
# for lang in src; do
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=1 && NR <=133317 {print "<2vi> " $0}' > $BPE_DATA/train.bpe.${lang}.1
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=133318 && NR <=266634 {print "<2en>" $0}' > $BPE_DATA/train.bpe.${lang}.2
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=266635 && NR <=489742 {print "<2ja> " $0}' > $BPE_DATA/train.bpe.${lang}.3
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=489743 && NR <=712850 {print "<2en> " $0}' > $BPE_DATA/train.bpe.${lang}.4
#     python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/train.bpe.${lang}.1 $BPE_DATA/train.bpe.${lang}.2 $BPE_DATA/train.bpe.${lang}.3 $BPE_DATA/train.bpe.${lang}.4 -o $TAGGED_DATA/train.${lang}
#     # python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/train.bpe.${lang}.1 $BPE_DATA/train.bpe.${lang}.4 -o $TAGGED_DATA/train.${lang}

#     ## validation
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=1 && NR <=1553 {print "<2vi> " $0}' > $BPE_DATA/valid.bpe.${lang}.1
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=1554 && NR <=3106 {print "<2en> " $0}' > $BPE_DATA/valid.bpe.${lang}.2
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=3107 && NR <=3977 {print "<2ja> " $0}' > $BPE_DATA/valid.bpe.${lang}.3
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=3978 && NR <=4848 {print "<2en> " $0}' > $BPE_DATA/valid.bpe.${lang}.4
#     python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/valid.bpe.${lang}.1 $BPE_DATA/valid.bpe.${lang}.2 $BPE_DATA/valid.bpe.${lang}.3 $BPE_DATA/valid.bpe.${lang}.4  -o $TAGGED_DATA/valid.${lang}
#     # python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/valid.bpe.${lang}.1 $BPE_DATA/valid.bpe.${lang}.4 -o $TAGGED_DATA/valid.${lang}

#     ## test
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=1 && NR <=1268 {print "<2vi> " $0}' > $BPE_DATA/test.bpe.${lang}.1
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=1269 && NR <=2536 {print "<2en> " $0}' > $BPE_DATA/test.bpe.${lang}.2
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=2537 && NR <=3730 {print "<2ja> " $0}' > $BPE_DATA/test.bpe.${lang}.3
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=3731 && NR <=4924 {print "<2en> " $0}' > $BPE_DATA/test.bpe.${lang}.4
#     python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/test.bpe.${lang}.1 $BPE_DATA/test.bpe.${lang}.2 $BPE_DATA/test.bpe.${lang}.3 $BPE_DATA/test.bpe.${lang}.4  -o $TAGGED_DATA/test.${lang}
#     # python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/test.bpe.${lang}.1 $BPE_DATA/test.bpe.${lang}.4 -o $TAGGED_DATA/test.${lang}
# done


# for lang in tgt; do
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=1 && NR <=133317 {print "<vi> " $0}' > $BPE_DATA/train.bpe.${lang}.1
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=133318 && NR <=266634 {print "<en> " $0}' > $BPE_DATA/train.bpe.${lang}.2
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=266635 && NR <=489742 {print "<ja> " $0}' > $BPE_DATA/train.bpe.${lang}.3
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=489743 && NR <=712850 {print "<en> " $0}' > $BPE_DATA/train.bpe.${lang}.4
#     python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/train.bpe.${lang}.1 $BPE_DATA/train.bpe.${lang}.2 $BPE_DATA/train.bpe.${lang}.3 $BPE_DATA/train.bpe.${lang}.4 -o $TAGGED_DATA/train.${lang}
#     # python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/train.bpe.${lang}.1 $BPE_DATA/train.bpe.${lang}.4 -o $TAGGED_DATA/train.${lang}

#     ## validation
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=1 && NR <=1553 {print "<vi> " $0}' > $BPE_DATA/valid.bpe.${lang}.1
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=1554 && NR <=3106 {print "<en> " $0}' > $BPE_DATA/valid.bpe.${lang}.2
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=3107 && NR <=3977 {print "<ja> " $0}' > $BPE_DATA/valid.bpe.${lang}.3
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=3978 && NR <=4848 {print "<en> " $0}' > $BPE_DATA/valid.bpe.${lang}.4
#     python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/valid.bpe.${lang}.1 $BPE_DATA/valid.bpe.${lang}.2 $BPE_DATA/valid.bpe.${lang}.3 $BPE_DATA/valid.bpe.${lang}.4  -o $TAGGED_DATA/valid.${lang}
#     # python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/valid.bpe.${lang}.1 $BPE_DATA/valid.bpe.${lang}.4 -o $TAGGED_DATA/valid.${lang}

#     ## test
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=1 && NR <=1268 {print "<vi> " $0}' > $BPE_DATA/test.bpe.${lang}.1
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=1269 && NR <=2536 {print "<en> " $0}' > $BPE_DATA/test.bpe.${lang}.2
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=2537 && NR <=3730 {print "<ja> " $0}' > $BPE_DATA/test.bpe.${lang}.3
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=3731 && NR <=4924 {print "<en> " $0}' > $BPE_DATA/test.bpe.${lang}.4
#     python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/test.bpe.${lang}.1 $BPE_DATA/test.bpe.${lang}.2 $BPE_DATA/test.bpe.${lang}.3 $BPE_DATA/test.bpe.${lang}.4  -o $TAGGED_DATA/test.${lang}
#     # python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/test.bpe.${lang}.1 $BPE_DATA/test.bpe.${lang}.4 -o $TAGGED_DATA/test.${lang}
# done

####################################################################################################################################
#### Model2
# for lang in src; do
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=1 && NR <=133317 {print "<en> <vi> " $0}' > $BPE_DATA/train.bpe.${lang}.1
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=133318 && NR <=266634 {print "<vi> <en> " $0}' > $BPE_DATA/train.bpe.${lang}.2
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=266635 && NR <=489742 {print "<en> <ja> " $0}' > $BPE_DATA/train.bpe.${lang}.3
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=489743 && NR <=712850 {print "<ja> <en> " $0}' > $BPE_DATA/train.bpe.${lang}.4
#     python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/train.bpe.${lang}.1 $BPE_DATA/train.bpe.${lang}.2 $BPE_DATA/train.bpe.${lang}.3 $BPE_DATA/train.bpe.${lang}.4 -o $TAGGED_DATA/train.${lang}
#     # python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/train.bpe.${lang}.1 $BPE_DATA/train.bpe.${lang}.4 -o $TAGGED_DATA/train.${lang}

#     ## validation
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=1 && NR <=1553 {print "<en> <vi> " $0}' > $BPE_DATA/valid.bpe.${lang}.1
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=1554 && NR <=3106 {print "<vi> <en> " $0}' > $BPE_DATA/valid.bpe.${lang}.2
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=3107 && NR <=3977 {print "<en> <ja> " $0}' > $BPE_DATA/valid.bpe.${lang}.3
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=3978 && NR <=4848 {print "<ja> <en> " $0}' > $BPE_DATA/valid.bpe.${lang}.4
#     python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/valid.bpe.${lang}.1 $BPE_DATA/valid.bpe.${lang}.2 $BPE_DATA/valid.bpe.${lang}.3 $BPE_DATA/valid.bpe.${lang}.4  -o $TAGGED_DATA/valid.${lang}
#     # python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/valid.bpe.${lang}.1 $BPE_DATA/valid.bpe.${lang}.4 -o $TAGGED_DATA/valid.${lang}

#     ## test
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=1 && NR <=1268 {print "<en> <vi> " $0}' > $BPE_DATA/test.bpe.${lang}.1
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=1269 && NR <=2536 {print "<vi> <en> " $0}' > $BPE_DATA/test.bpe.${lang}.2
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=2537 && NR <=3730 {print "<en> <ja> " $0}' > $BPE_DATA/test.bpe.${lang}.3
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=3731 && NR <=4924 {print "<ja> <en> " $0}' > $BPE_DATA/test.bpe.${lang}.4
#     python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/test.bpe.${lang}.1 $BPE_DATA/test.bpe.${lang}.2 $BPE_DATA/test.bpe.${lang}.3 $BPE_DATA/test.bpe.${lang}.4  -o $TAGGED_DATA/test.${lang}
#     # python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/test.bpe.${lang}.1 $BPE_DATA/test.bpe.${lang}.4 -o $TAGGED_DATA/test.${lang}
# done


# for lang in tgt; do
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=1 && NR <=133317 {print "<vi> " $0}' > $BPE_DATA/train.bpe.${lang}.1
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=133318 && NR <=266634 {print "<en> " $0}' > $BPE_DATA/train.bpe.${lang}.2
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=266635 && NR <=489742 {print "<ja> " $0}' > $BPE_DATA/train.bpe.${lang}.3
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=489743 && NR <=712850 {print "<en> " $0}' > $BPE_DATA/train.bpe.${lang}.4
#     python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/train.bpe.${lang}.1 $BPE_DATA/train.bpe.${lang}.2 $BPE_DATA/train.bpe.${lang}.3 $BPE_DATA/train.bpe.${lang}.4 -o $TAGGED_DATA/train.${lang}
#     # python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/train.bpe.${lang}.1 $BPE_DATA/train.bpe.${lang}.4 -o $TAGGED_DATA/train.${lang}

#     ## validation
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=1 && NR <=1553 {print "<vi> " $0}' > $BPE_DATA/valid.bpe.${lang}.1
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=1554 && NR <=3106 {print "<en> " $0}' > $BPE_DATA/valid.bpe.${lang}.2
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=3107 && NR <=3977 {print "<ja> " $0}' > $BPE_DATA/valid.bpe.${lang}.3
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=3978 && NR <=4848 {print "<en> " $0}' > $BPE_DATA/valid.bpe.${lang}.4
#     python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/valid.bpe.${lang}.1 $BPE_DATA/valid.bpe.${lang}.2 $BPE_DATA/valid.bpe.${lang}.3 $BPE_DATA/valid.bpe.${lang}.4  -o $TAGGED_DATA/valid.${lang}
#     # python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/valid.bpe.${lang}.1 $BPE_DATA/valid.bpe.${lang}.4 -o $TAGGED_DATA/valid.${lang}

#     ## test
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=1 && NR <=1268 {print "<vi> " $0}' > $BPE_DATA/test.bpe.${lang}.1
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=1269 && NR <=2536 {print "<en> " $0}' > $BPE_DATA/test.bpe.${lang}.2
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=2537 && NR <=3730 {print "<ja> " $0}' > $BPE_DATA/test.bpe.${lang}.3
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=3731 && NR <=4924 {print "<en> " $0}' > $BPE_DATA/test.bpe.${lang}.4
#     python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/test.bpe.${lang}.1 $BPE_DATA/test.bpe.${lang}.2 $BPE_DATA/test.bpe.${lang}.3 $BPE_DATA/test.bpe.${lang}.4  -o $TAGGED_DATA/test.${lang}
#     # python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/test.bpe.${lang}.1 $BPE_DATA/test.bpe.${lang}.4 -o $TAGGED_DATA/test.${lang}
# done

####################################################################################################################################
#### Model3
# for lang in src; do
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=1 && NR <=133317 {print "<vi> " $0}' > $BPE_DATA/train.bpe.${lang}.1
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=133318 && NR <=266634 {print "<en> " $0}' > $BPE_DATA/train.bpe.${lang}.2
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=266635 && NR <=489742 {print "<ja> " $0}' > $BPE_DATA/train.bpe.${lang}.3
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=489743 && NR <=712850 {print "<en> " $0}' > $BPE_DATA/train.bpe.${lang}.4
#     python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/train.bpe.${lang}.1 $BPE_DATA/train.bpe.${lang}.2 $BPE_DATA/train.bpe.${lang}.3 $BPE_DATA/train.bpe.${lang}.4 -o $TAGGED_DATA/train.${lang}
#     # python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/train.bpe.${lang}.1 $BPE_DATA/train.bpe.${lang}.4 -o $TAGGED_DATA/train.${lang}

#     ## validation
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=1 && NR <=1553 {print "<vi> " $0}' > $BPE_DATA/valid.bpe.${lang}.1
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=1554 && NR <=3106 {print "<en> " $0}' > $BPE_DATA/valid.bpe.${lang}.2
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=3107 && NR <=3977 {print "<ja> " $0}' > $BPE_DATA/valid.bpe.${lang}.3
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=3978 && NR <=4848 {print "<en> " $0}' > $BPE_DATA/valid.bpe.${lang}.4
#     python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/valid.bpe.${lang}.1 $BPE_DATA/valid.bpe.${lang}.2 $BPE_DATA/valid.bpe.${lang}.3 $BPE_DATA/valid.bpe.${lang}.4  -o $TAGGED_DATA/valid.${lang}
#     # python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/valid.bpe.${lang}.1 $BPE_DATA/valid.bpe.${lang}.4 -o $TAGGED_DATA/valid.${lang}

#     ## test
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=1 && NR <=1268 {print "<vi> " $0}' > $BPE_DATA/test.bpe.${lang}.1
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=1269 && NR <=2536 {print "<en> " $0}' > $BPE_DATA/test.bpe.${lang}.2
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=2537 && NR <=3730 {print "<ja> " $0}' > $BPE_DATA/test.bpe.${lang}.3
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=3731 && NR <=4924 {print "<en> " $0}' > $BPE_DATA/test.bpe.${lang}.4
#     python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/test.bpe.${lang}.1 $BPE_DATA/test.bpe.${lang}.2 $BPE_DATA/test.bpe.${lang}.3 $BPE_DATA/test.bpe.${lang}.4  -o $TAGGED_DATA/test.${lang}
#     # python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/test.bpe.${lang}.1 $BPE_DATA/test.bpe.${lang}.4 -o $TAGGED_DATA/test.${lang}
# done


# for lang in tgt; do
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=1 && NR <=133317 {print  $0}' > $BPE_DATA/train.bpe.${lang}.1
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=133318 && NR <=266634 {print   $0}' > $BPE_DATA/train.bpe.${lang}.2
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=266635 && NR <=489742 {print  $0}' > $BPE_DATA/train.bpe.${lang}.3
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=489743 && NR <=712850 {print  $0}' > $BPE_DATA/train.bpe.${lang}.4
#     python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/train.bpe.${lang}.1 $BPE_DATA/train.bpe.${lang}.2 $BPE_DATA/train.bpe.${lang}.3 $BPE_DATA/train.bpe.${lang}.4 -o $TAGGED_DATA/train.${lang}
#     # python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/train.bpe.${lang}.1 $BPE_DATA/train.bpe.${lang}.4 -o $TAGGED_DATA/train.${lang}

#     ## validation
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=1 && NR <=1553 {print  $0}' > $BPE_DATA/valid.bpe.${lang}.1
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=1554 && NR <=3106 {print  $0}' > $BPE_DATA/valid.bpe.${lang}.2
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=3107 && NR <=3977 {print  $0}' > $BPE_DATA/valid.bpe.${lang}.3
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=3978 && NR <=4848 {print  $0}' > $BPE_DATA/valid.bpe.${lang}.4
#     python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/valid.bpe.${lang}.1 $BPE_DATA/valid.bpe.${lang}.2 $BPE_DATA/valid.bpe.${lang}.3 $BPE_DATA/valid.bpe.${lang}.4  -o $TAGGED_DATA/valid.${lang}
#     # python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/valid.bpe.${lang}.1 $BPE_DATA/valid.bpe.${lang}.4 -o $TAGGED_DATA/valid.${lang}

#     ## test
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=1 && NR <=1268 {print  $0}' > $BPE_DATA/test.bpe.${lang}.1
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=1269 && NR <=2536 {print  $0}' > $BPE_DATA/test.bpe.${lang}.2
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=2537 && NR <=3730 {print  $0}' > $BPE_DATA/test.bpe.${lang}.3
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=3731 && NR <=4924 {print  $0}' > $BPE_DATA/test.bpe.${lang}.4
#     python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/test.bpe.${lang}.1 $BPE_DATA/test.bpe.${lang}.2 $BPE_DATA/test.bpe.${lang}.3 $BPE_DATA/test.bpe.${lang}.4  -o $TAGGED_DATA/test.${lang}
#     # python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/test.bpe.${lang}.1 $BPE_DATA/test.bpe.${lang}.4 -o $TAGGED_DATA/test.${lang}
# done

####################################################################################################################################
#### Model4
# for lang in src; do
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=1 && NR <=133317 {print  $0}' > $BPE_DATA/train.bpe.${lang}.1
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=133318 && NR <=266634 {print   $0}' > $BPE_DATA/train.bpe.${lang}.2
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=266635 && NR <=489742 {print  $0}' > $BPE_DATA/train.bpe.${lang}.3
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=489743 && NR <=712850 {print  $0}' > $BPE_DATA/train.bpe.${lang}.4
#     python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/train.bpe.${lang}.1 $BPE_DATA/train.bpe.${lang}.2 $BPE_DATA/train.bpe.${lang}.3 $BPE_DATA/train.bpe.${lang}.4 -o $TAGGED_DATA/train.${lang}
#     # python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/train.bpe.${lang}.1 $BPE_DATA/train.bpe.${lang}.4 -o $TAGGED_DATA/train.${lang}

#     ## validation
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=1 && NR <=1553 {print  $0}' > $BPE_DATA/valid.bpe.${lang}.1
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=1554 && NR <=3106 {print  $0}' > $BPE_DATA/valid.bpe.${lang}.2
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=3107 && NR <=3977 {print  $0}' > $BPE_DATA/valid.bpe.${lang}.3
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=3978 && NR <=4848 {print  $0}' > $BPE_DATA/valid.bpe.${lang}.4
#     python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/valid.bpe.${lang}.1 $BPE_DATA/valid.bpe.${lang}.2 $BPE_DATA/valid.bpe.${lang}.3 $BPE_DATA/valid.bpe.${lang}.4  -o $TAGGED_DATA/valid.${lang}
#     # python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/valid.bpe.${lang}.1 $BPE_DATA/valid.bpe.${lang}.4 -o $TAGGED_DATA/valid.${lang}

#     ## test
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=1 && NR <=1268 {print  $0}' > $BPE_DATA/test.bpe.${lang}.1
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=1269 && NR <=2536 {print  $0}' > $BPE_DATA/test.bpe.${lang}.2
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=2537 && NR <=3730 {print  $0}' > $BPE_DATA/test.bpe.${lang}.3
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=3731 && NR <=4924 {print  $0}' > $BPE_DATA/test.bpe.${lang}.4
#     python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/test.bpe.${lang}.1 $BPE_DATA/test.bpe.${lang}.2 $BPE_DATA/test.bpe.${lang}.3 $BPE_DATA/test.bpe.${lang}.4  -o $TAGGED_DATA/test.${lang}
#     # python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/test.bpe.${lang}.1 $BPE_DATA/test.bpe.${lang}.4 -o $TAGGED_DATA/test.${lang}
# done

# for lang in tgt; do
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=1 && NR <=133317 {print "<vi> " $0}' > $BPE_DATA/train.bpe.${lang}.1
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=133318 && NR <=266634 {print "<en> " $0}' > $BPE_DATA/train.bpe.${lang}.2
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=266635 && NR <=489742 {print "<ja> " $0}' > $BPE_DATA/train.bpe.${lang}.3
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=489743 && NR <=712850 {print "<en> " $0}' > $BPE_DATA/train.bpe.${lang}.4
#     python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/train.bpe.${lang}.1 $BPE_DATA/train.bpe.${lang}.2 $BPE_DATA/train.bpe.${lang}.3 $BPE_DATA/train.bpe.${lang}.4 -o $TAGGED_DATA/train.${lang}
#     # python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/train.bpe.${lang}.1 $BPE_DATA/train.bpe.${lang}.4 -o $TAGGED_DATA/train.${lang}

#     ## validation
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=1 && NR <=1553 {print "<vi> " $0}' > $BPE_DATA/valid.bpe.${lang}.1
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=1554 && NR <=3106 {print "<en> " $0}' > $BPE_DATA/valid.bpe.${lang}.2
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=3107 && NR <=3977 {print "<ja> " $0}' > $BPE_DATA/valid.bpe.${lang}.3
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=3978 && NR <=4848 {print "<en> " $0}' > $BPE_DATA/valid.bpe.${lang}.4
#     python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/valid.bpe.${lang}.1 $BPE_DATA/valid.bpe.${lang}.2 $BPE_DATA/valid.bpe.${lang}.3 $BPE_DATA/valid.bpe.${lang}.4  -o $TAGGED_DATA/valid.${lang}
#     # python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/valid.bpe.${lang}.1 $BPE_DATA/valid.bpe.${lang}.4 -o $TAGGED_DATA/valid.${lang}

#     ## test
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=1 && NR <=1268 {print "<vi> " $0}' > $BPE_DATA/test.bpe.${lang}.1
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=1269 && NR <=2536 {print "<en> " $0}' > $BPE_DATA/test.bpe.${lang}.2
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=2537 && NR <=3730 {print "<ja> " $0}' > $BPE_DATA/test.bpe.${lang}.3
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=3731 && NR <=4924 {print "<en> " $0}' > $BPE_DATA/test.bpe.${lang}.4
#     python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/test.bpe.${lang}.1 $BPE_DATA/test.bpe.${lang}.2 $BPE_DATA/test.bpe.${lang}.3 $BPE_DATA/test.bpe.${lang}.4  -o $TAGGED_DATA/test.${lang}
#     # python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/test.bpe.${lang}.1 $BPE_DATA/test.bpe.${lang}.4 -o $TAGGED_DATA/test.${lang}
# done

####################################################################################################################################
#### Model5
# for lang in src; do
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=1 && NR <=133317 {print "<en> " $0}' > $BPE_DATA/train.bpe.${lang}.1
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=133318 && NR <=266634 {print "<vi> " $0}' > $BPE_DATA/train.bpe.${lang}.2
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=266635 && NR <=489742 {print "<en> " $0}' > $BPE_DATA/train.bpe.${lang}.3
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=489743 && NR <=712850 {print "<ja> " $0}' > $BPE_DATA/train.bpe.${lang}.4
#     python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/train.bpe.${lang}.1 $BPE_DATA/train.bpe.${lang}.2 $BPE_DATA/train.bpe.${lang}.3 $BPE_DATA/train.bpe.${lang}.4 -o $TAGGED_DATA/train.${lang}
#     # python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/train.bpe.${lang}.1 $BPE_DATA/train.bpe.${lang}.4 -o $TAGGED_DATA/train.${lang}

#     ## validation
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=1 && NR <=1553 {print "<en> " $0}' > $BPE_DATA/valid.bpe.${lang}.1
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=1554 && NR <=3106 {print "<vi> " $0}' > $BPE_DATA/valid.bpe.${lang}.2
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=3107 && NR <=3977 {print "<en> " $0}' > $BPE_DATA/valid.bpe.${lang}.3
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=3978 && NR <=4848 {print "<ja> " $0}' > $BPE_DATA/valid.bpe.${lang}.4
#     python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/valid.bpe.${lang}.1 $BPE_DATA/valid.bpe.${lang}.2 $BPE_DATA/valid.bpe.${lang}.3 $BPE_DATA/valid.bpe.${lang}.4  -o $TAGGED_DATA/valid.${lang}
#     # python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/valid.bpe.${lang}.1 $BPE_DATA/valid.bpe.${lang}.4 -o $TAGGED_DATA/valid.${lang}

#     ## test
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=1 && NR <=1268 {print "<en> " $0}' > $BPE_DATA/test.bpe.${lang}.1
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=1269 && NR <=2536 {print "<vi> " $0}' > $BPE_DATA/test.bpe.${lang}.2
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=2537 && NR <=3730 {print "<en> " $0}' > $BPE_DATA/test.bpe.${lang}.3
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=3731 && NR <=4924 {print "<ja> " $0}' > $BPE_DATA/test.bpe.${lang}.4
#     python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/test.bpe.${lang}.1 $BPE_DATA/test.bpe.${lang}.2 $BPE_DATA/test.bpe.${lang}.3 $BPE_DATA/test.bpe.${lang}.4  -o $TAGGED_DATA/test.${lang}
#     # python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/test.bpe.${lang}.1 $BPE_DATA/test.bpe.${lang}.4 -o $TAGGED_DATA/test.${lang}
# done


# for lang in tgt; do
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=1 && NR <=133317 {print "<vi> " $0}' > $BPE_DATA/train.bpe.${lang}.1
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=133318 && NR <=266634 {print "<en> " $0}' > $BPE_DATA/train.bpe.${lang}.2
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=266635 && NR <=489742 {print "<ja> " $0}' > $BPE_DATA/train.bpe.${lang}.3
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=489743 && NR <=712850 {print "<en> " $0}' > $BPE_DATA/train.bpe.${lang}.4
#     python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/train.bpe.${lang}.1 $BPE_DATA/train.bpe.${lang}.2 $BPE_DATA/train.bpe.${lang}.3 $BPE_DATA/train.bpe.${lang}.4 -o $TAGGED_DATA/train.${lang}
#     # python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/train.bpe.${lang}.1 $BPE_DATA/train.bpe.${lang}.4 -o $TAGGED_DATA/train.${lang}

#     ## validation
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=1 && NR <=1553 {print "<vi> " $0}' > $BPE_DATA/valid.bpe.${lang}.1
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=1554 && NR <=3106 {print "<en> " $0}' > $BPE_DATA/valid.bpe.${lang}.2
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=3107 && NR <=3977 {print "<ja> " $0}' > $BPE_DATA/valid.bpe.${lang}.3
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=3978 && NR <=4848 {print "<en> " $0}' > $BPE_DATA/valid.bpe.${lang}.4
#     python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/valid.bpe.${lang}.1 $BPE_DATA/valid.bpe.${lang}.2 $BPE_DATA/valid.bpe.${lang}.3 $BPE_DATA/valid.bpe.${lang}.4  -o $TAGGED_DATA/valid.${lang}
#     # python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/valid.bpe.${lang}.1 $BPE_DATA/valid.bpe.${lang}.4 -o $TAGGED_DATA/valid.${lang}

#     ## test
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=1 && NR <=1268 {print "<vi> " $0}' > $BPE_DATA/test.bpe.${lang}.1
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=1269 && NR <=2536 {print "<en> " $0}' > $BPE_DATA/test.bpe.${lang}.2
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=2537 && NR <=3730 {print "<ja> " $0}' > $BPE_DATA/test.bpe.${lang}.3
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=3731 && NR <=4924 {print "<en> " $0}' > $BPE_DATA/test.bpe.${lang}.4
#     python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/test.bpe.${lang}.1 $BPE_DATA/test.bpe.${lang}.2 $BPE_DATA/test.bpe.${lang}.3 $BPE_DATA/test.bpe.${lang}.4  -o $TAGGED_DATA/test.${lang}
#     # python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/test.bpe.${lang}.1 $BPE_DATA/test.bpe.${lang}.4 -o $TAGGED_DATA/test.${lang}
# done


####################################################################################################################################
# MODEL-S(small): Using 10000 parallel ja-vi dataset to train models
####################################################################################################################################

#### model-s-1
# for lang in src; do
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=1 && NR <=133317 {print "<vi> " $0}' > $BPE_DATA/train.bpe.${lang}.1
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=133318 && NR <=266634 {print "<en> " $0}' > $BPE_DATA/train.bpe.${lang}.2
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=266635 && NR <=489742 {print "<ja> " $0}' > $BPE_DATA/train.bpe.${lang}.3
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=489743 && NR <=712850 {print "<en> " $0}' > $BPE_DATA/train.bpe.${lang}.4
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=712851 && NR <=722850 {print "<vi> " $0}' > $BPE_DATA/train.bpe.${lang}.5
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=722851 && NR <=732850 {print "<ja> " $0}' > $BPE_DATA/train.bpe.${lang}.6
#     python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/train.bpe.${lang}.1 $BPE_DATA/train.bpe.${lang}.2 $BPE_DATA/train.bpe.${lang}.3 \
#                                              $BPE_DATA/train.bpe.${lang}.4 $BPE_DATA/train.bpe.${lang}.5 $BPE_DATA/train.bpe.${lang}.6 \
#                                              -o $TAGGED_DATA/train.${lang}
#     # python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/train.bpe.${lang}.1 $BPE_DATA/train.bpe.${lang}.4 -o $TAGGED_DATA/train.${lang}

#     ## validation
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=1 && NR <=1553 {print "<vi> " $0}' > $BPE_DATA/valid.bpe.${lang}.1
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=1554 && NR <=3106 {print "<en> " $0}' > $BPE_DATA/valid.bpe.${lang}.2
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=3107 && NR <=3977 {print "<ja> " $0}' > $BPE_DATA/valid.bpe.${lang}.3
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=3978 && NR <=4848 {print "<en> " $0}' > $BPE_DATA/valid.bpe.${lang}.4
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=4849 && NR <=5406 {print "<vi> " $0}' > $BPE_DATA/valid.bpe.${lang}.5
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=5407 && NR <=5964 {print "<ja> " $0}' > $BPE_DATA/valid.bpe.${lang}.6
#     python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/valid.bpe.${lang}.1 $BPE_DATA/valid.bpe.${lang}.2 \
#                                                 $BPE_DATA/valid.bpe.${lang}.3 $BPE_DATA/valid.bpe.${lang}.4 \
#                                                 $BPE_DATA/valid.bpe.${lang}.5 $BPE_DATA/valid.bpe.${lang}.6 \
#                                                 -o $TAGGED_DATA/valid.${lang}
#     # python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/valid.bpe.${lang}.1 $BPE_DATA/valid.bpe.${lang}.4 -o $TAGGED_DATA/valid.${lang}

#     ## test
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=1 && NR <=1268 {print "<vi> " $0}' > $BPE_DATA/test.bpe.${lang}.1
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=1269 && NR <=2536 {print "<en> " $0}' > $BPE_DATA/test.bpe.${lang}.2
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=2537 && NR <=3730 {print "<ja> " $0}' > $BPE_DATA/test.bpe.${lang}.3
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=3731 && NR <=4924 {print "<en> " $0}' > $BPE_DATA/test.bpe.${lang}.4
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=4925 && NR <=6140 {print "<vi> " $0}' > $BPE_DATA/test.bpe.${lang}.5
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=6141 && NR <=7355 {print "<ja> " $0}' > $BPE_DATA/test.bpe.${lang}.6
#     python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/test.bpe.${lang}.1 $BPE_DATA/test.bpe.${lang}.2 \
#                                                     $BPE_DATA/test.bpe.${lang}.3 $BPE_DATA/test.bpe.${lang}.4 \
#                                                     $BPE_DATA/test.bpe.${lang}.5 $BPE_DATA/test.bpe.${lang}.6 \
#                                                      -o $TAGGED_DATA/test.${lang}
#     # python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/test.bpe.${lang}.1 $BPE_DATA/test.bpe.${lang}.4 -o $TAGGED_DATA/test.${lang}
# done


# for lang in tgt; do
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=1 && NR <=133317 {print  $0}' > $BPE_DATA/train.bpe.${lang}.1
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=133318 && NR <=266634 {print   $0}' > $BPE_DATA/train.bpe.${lang}.2
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=266635 && NR <=489742 {print  $0}' > $BPE_DATA/train.bpe.${lang}.3
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=489743 && NR <=712850 {print  $0}' > $BPE_DATA/train.bpe.${lang}.4
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=712851 && NR <=722850 {print $0}' > $BPE_DATA/train.bpe.${lang}.5
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=722851 && NR <=732850 {print $0}' > $BPE_DATA/train.bpe.${lang}.6
#     python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/train.bpe.${lang}.1 $BPE_DATA/train.bpe.${lang}.2 $BPE_DATA/train.bpe.${lang}.3 \
#                                              $BPE_DATA/train.bpe.${lang}.4 $BPE_DATA/train.bpe.${lang}.5 $BPE_DATA/train.bpe.${lang}.6 \
#                                              -o $TAGGED_DATA/train.${lang}
#     # python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/train.bpe.${lang}.1 $BPE_DATA/train.bpe.${lang}.4 -o $TAGGED_DATA/train.${lang}

#     ## validation
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=1 && NR <=1553 {print  $0}' > $BPE_DATA/valid.bpe.${lang}.1
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=1554 && NR <=3106 {print  $0}' > $BPE_DATA/valid.bpe.${lang}.2
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=3107 && NR <=3977 {print  $0}' > $BPE_DATA/valid.bpe.${lang}.3
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=3978 && NR <=4848 {print  $0}' > $BPE_DATA/valid.bpe.${lang}.4
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=4849 && NR <=5406 {print  $0}' > $BPE_DATA/valid.bpe.${lang}.5
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=5407 && NR <=5964 {print  $0}' > $BPE_DATA/valid.bpe.${lang}.6
#     python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/valid.bpe.${lang}.1 $BPE_DATA/valid.bpe.${lang}.2 \
#                                                 $BPE_DATA/valid.bpe.${lang}.3 $BPE_DATA/valid.bpe.${lang}.4 \
#                                                 $BPE_DATA/valid.bpe.${lang}.5 $BPE_DATA/valid.bpe.${lang}.6 \
#                                                 -o $TAGGED_DATA/valid.${lang}
#     # python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/valid.bpe.${lang}.1 $BPE_DATA/valid.bpe.${lang}.4 -o $TAGGED_DATA/valid.${lang}

#     ## test
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=1 && NR <=1268 {print  $0}' > $BPE_DATA/test.bpe.${lang}.1
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=1269 && NR <=2536 {print  $0}' > $BPE_DATA/test.bpe.${lang}.2
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=2537 && NR <=3730 {print  $0}' > $BPE_DATA/test.bpe.${lang}.3
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=3731 && NR <=4924 {print  $0}' > $BPE_DATA/test.bpe.${lang}.4
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=4925 && NR <=6140 {print  $0}' > $BPE_DATA/test.bpe.${lang}.5
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=6141 && NR <=7355 {print  $0}' > $BPE_DATA/test.bpe.${lang}.6
#     python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/test.bpe.${lang}.1 $BPE_DATA/test.bpe.${lang}.2 \
#                                                     $BPE_DATA/test.bpe.${lang}.3 $BPE_DATA/test.bpe.${lang}.4 \
#                                                     $BPE_DATA/test.bpe.${lang}.5 $BPE_DATA/test.bpe.${lang}.6 \
#                                                      -o $TAGGED_DATA/test.${lang}
#     # python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/test.bpe.${lang}.1 $BPE_DATA/test.bpe.${lang}.4 -o $TAGGED_DATA/test.${lang}
# done

# fairseq-preprocess -s src -t tgt \
# 			--destdir $BIN_DATA \
# 			--trainpref $TAGGED_DATA/train \
# 			--validpref $TAGGED_DATA/valid \
# 			--testpref $TAGGED_DATA/test \
#             --joined-dictionary \
# 			--workers 32 \
#             2>&1 | tee $EXPDIR/logs/preprocess

# for lang in tgt; do
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=1 && NR <=133317 {print "<b-vi> " $0 "    <e-vi>"}' > $BPE_DATA/train.bpe.${lang}.1
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=133318 && NR <=266634 {print "<b-en> " $0 "    <e-en>"}' > $BPE_DATA/train.bpe.${lang}.2
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=266635 && NR <=489742 {print "<b-ja> " $0 "    <e-ja>"}' > $BPE_DATA/train.bpe.${lang}.3
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=489743 && NR <=712850 {print "<b-en> " $0 "    <e-en>"}' > $BPE_DATA/train.bpe.${lang}.4
#     python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/train.bpe.${lang}.1 $BPE_DATA/train.bpe.${lang}.2 $BPE_DATA/train.bpe.${lang}.3 $BPE_DATA/train.bpe.${lang}.4 -o $TAGGED_DATA/train.${lang}
#     # python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/train.bpe.${lang}.1 $BPE_DATA/train.bpe.${lang}.4 -o $TAGGED_DATA/train.${lang}

#     ## validation
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=1 && NR <=1553 {print "<b-vi> " $0 "   <e-vi>"}' > $BPE_DATA/valid.bpe.${lang}.1
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=1554 && NR <=3106 {print "<b-en> " $0 "    <e-en>"}' > $BPE_DATA/valid.bpe.${lang}.2
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=3107 && NR <=3977 {print "<b-ja> " $0 "    <e-ja>"}' > $BPE_DATA/valid.bpe.${lang}.3
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=3978 && NR <=4848 {print "<b-en> " $0 "    <e-en>"}' > $BPE_DATA/valid.bpe.${lang}.4
#     python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/valid.bpe.${lang}.1 $BPE_DATA/valid.bpe.${lang}.2 $BPE_DATA/valid.bpe.${lang}.3 $BPE_DATA/valid.bpe.${lang}.4  -o $TAGGED_DATA/valid.${lang}
#     # python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/valid.bpe.${lang}.1 $BPE_DATA/valid.bpe.${lang}.4 -o $TAGGED_DATA/valid.${lang}

#     ## test
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=1 && NR <=1268 {print "<b-vi> " $0 "    <e-vi>"}' > $BPE_DATA/test.bpe.${lang}.1
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=1269 && NR <=2536 {print "<b-en> " $0 "    <e-en>" }' > $BPE_DATA/test.bpe.${lang}.2
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=2537 && NR <=3730 {print "<b-ja> " $0 "    <e-ja>" }' > $BPE_DATA/test.bpe.${lang}.3
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=3731 && NR <=4924 {print "<b-en> " $0 "    <e-en>"}' > $BPE_DATA/test.bpe.${lang}.4
#     python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/test.bpe.${lang}.1 $BPE_DATA/test.bpe.${lang}.2 $BPE_DATA/test.bpe.${lang}.3 $BPE_DATA/test.bpe.${lang}.4  -o $TAGGED_DATA/test.${lang}
#     # python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/test.bpe.${lang}.1 $BPE_DATA/test.bpe.${lang}.4 -o $TAGGED_DATA/test.${lang}
# done

# for lang in tgt; do
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=1 && NR <=133317 {print  $0}' > $BPE_DATA/train.bpe.${lang}.1
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=133318 && NR <=266634 {print  $0}' > $BPE_DATA/train.bpe.${lang}.2
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=266635 && NR <=489742 {print  $0}' > $BPE_DATA/train.bpe.${lang}.3
#     cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=489743 && NR <=712850 {print  $0}' > $BPE_DATA/train.bpe.${lang}.4
#     python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/train.bpe.${lang}.1 $BPE_DATA/train.bpe.${lang}.2 $BPE_DATA/train.bpe.${lang}.3 $BPE_DATA/train.bpe.${lang}.4 -o $TAGGED_DATA/train.${lang}
#     # python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/train.bpe.${lang}.1 $BPE_DATA/train.bpe.${lang}.4 -o $TAGGED_DATA/train.${lang}

#     ## validation
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=1 && NR <=1553 {print  $0}' > $BPE_DATA/valid.bpe.${lang}.1
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=1554 && NR <=3106 {print  $0}' > $BPE_DATA/valid.bpe.${lang}.2
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=3107 && NR <=3977 {print  $0}' > $BPE_DATA/valid.bpe.${lang}.3
#     cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=3978 && NR <=4848 {print  $0}' > $BPE_DATA/valid.bpe.${lang}.4
#     python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/valid.bpe.${lang}.1 $BPE_DATA/valid.bpe.${lang}.2 $BPE_DATA/valid.bpe.${lang}.3 $BPE_DATA/valid.bpe.${lang}.4 -o $TAGGED_DATA/valid.${lang}
#     # python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/valid.bpe.${lang}.1 $BPE_DATA/valid.bpe.${lang}.4 -o $TAGGED_DATA/valid.${lang}

#     ## test
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=1 && NR <=1268 {print  $0}' > $BPE_DATA/test.bpe.${lang}.1
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=1269 && NR <=2536 {print  $0}' > $BPE_DATA/test.bpe.${lang}.2
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=2537 && NR <=3730 {print  $0}' > $BPE_DATA/test.bpe.${lang}.3
#     cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=3731 && NR <=4924 {print  $0}' > $BPE_DATA/test.bpe.${lang}.4
#     python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/test.bpe.${lang}.1 $BPE_DATA/test.bpe.${lang}.2 $BPE_DATA/test.bpe.${lang}.3 $BPE_DATA/test.bpe.${lang}.4 -o $TAGGED_DATA/test.${lang}
#     # python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/test.bpe.${lang}.1 $BPE_DATA/test.bpe.${lang}.4 -o $TAGGED_DATA/test.${lang}
# done