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
done


# Tokenization
echo "=> Tokenizing..."
for set in $DATASET_NAME; do
    $TOKENIZER -l en < ${NORMALIZED_DATA}/${set}.en-vi.en > ${TOKENIZED_DATA}/${set}.en-vi.en
    $TOKENIZER -l en < ${NORMALIZED_DATA}/${set}.en-ja.en > ${TOKENIZED_DATA}/${set}.en-ja.en
    python3.6 ${EXPDIR}/preprocess/tokenize-vi.py ${NORMALIZED_DATA}/${set}.en-vi.vi ${TOKENIZED_DATA}/${set}.en-vi.vi
done

cat ${TOKENIZED_DATA}/${set}.en-vi.en ${TOKENIZED_DATA}/${set}.en-ja.en > ${TOKENIZED_DATA}/train.corpus.en

# Truecaser
echo "=> Truecasing..."
echo "Training for English..."
$TRUECASER_TRAIN --model $DATASET/tmp/truecase.model.en --corpus ${TOKENIZED_DATA}/train.corpus.en

echo "Training for Vietnamese"
$TRUECASER_TRAIN --model $DATASET/tmp/truecase.model.vi --corpus ${TOKENIZED_DATA}/train.en-vi.vi

for set in $DATASET_NAME; do
    $TRUECASER --model $DATASET/tmp/truecase.model.en < ${TOKENIZED_DATA}/${set}.en-vi.en > ${TRUECASED_DATA}/${set}.en-vi.en
    $TRUECASER --model $DATASET/tmp/truecase.model.en < ${TOKENIZED_DATA}/${set}.en-ja.en > ${TRUECASED_DATA}/${set}.en-ja.en
    $TRUECASER --model $DATASET/tmp/truecase.model.vi < ${TOKENIZED_DATA}/${set}.en-vi.vi > ${TRUECASED_DATA}/${set}.en-vi.vi
    mecab -Owakati ${NORMALIZED_DATA}/${set}.en-ja.ja > ${TRUECASED_DATA}/${set}.en-ja.ja 
done

for set in $DATASET_NAME; do
    cat ${TRUECASED_DATA}/${set}.en-vi.en ${TRUECASED_DATA}/${set}.en-vi.vi ${TRUECASED_DATA}/${set}.en-ja.en ${TRUECASED_DATA}/${set}.en-ja.ja > ${TRUECASED_DATA}/${set}.src
    cat ${TRUECASED_DATA}/${set}.en-vi.vi ${TRUECASED_DATA}/${set}.en-vi.en ${TRUECASED_DATA}/${set}.en-ja.ja ${TRUECASED_DATA}/${set}.en-ja.en > ${TRUECASED_DATA}/${set}.tgt
done

# learn bpe model with training data
subword-nmt learn-bpe -s ${BPE_TOKENS} < ${TRUECASED_DATA}/train.src > $DATASET/tmp/bpe.${BPE_TOKENS}.model

for set in $DATASET_NAME; do
    for lang in src tgt; do
        subword-nmt apply-bpe -c $DATASET/tmp/bpe.${BPE_TOKENS}.model < ${TRUECASED_DATA}/${set}.${lang} > $BPE_DATA/${set}.bpe.${lang}
    done
done

# adding tags
## train data
for lang in src; do
    cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=1 && NR <=133317 {print "<2vi> " $0}' > $BPE_DATA/train.bpe.${lang}.1
    cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=133318 && NR <=266634 {print "<2en> " $0}' > $BPE_DATA/train.bpe.${lang}.2
    cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=266635 && NR <=489742 {print "<2ja> " $0}' > $BPE_DATA/train.bpe.${lang}.3
    cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=489743 && NR <=712850 {print "<2en> " $0}' > $BPE_DATA/train.bpe.${lang}.4
    # python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/train.bpe.${lang}.1 $BPE_DATA/train.bpe.${lang}.2 $BPE_DATA/train.bpe.${lang}.3 $BPE_DATA/train.bpe.${lang}.4 -o $TAGGED_DATA/train.${lang}
    python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/train.bpe.${lang}.1 $BPE_DATA/train.bpe.${lang}.4 -o $TAGGED_DATA/train.${lang}

    ## validation
    cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=1 && NR <=1553 {print "<2vi> " $0}' > $BPE_DATA/valid.bpe.${lang}.1
    cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=1554 && NR <=3106 {print "<2en> " $0}' > $BPE_DATA/valid.bpe.${lang}.2
    cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=3107 && NR <=3977 {print "<2ja> " $0}' > $BPE_DATA/valid.bpe.${lang}.3
    cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=3978 && NR <=4848 {print "<2en> " $0}' > $BPE_DATA/valid.bpe.${lang}.4
    # python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/valid.bpe.${lang}.1 $BPE_DATA/valid.bpe.${lang}.2 $BPE_DATA/valid.bpe.${lang}.3 $BPE_DATA/valid.bpe.${lang}.4  -o $TAGGED_DATA/valid.${lang}
    python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/valid.bpe.${lang}.1 $BPE_DATA/valid.bpe.${lang}.4 -o $TAGGED_DATA/valid.${lang}

    ## test
    cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=1 && NR <=1268 {print "<2vi> " $0}' > $BPE_DATA/test.bpe.${lang}.1
    cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=1269 && NR <=2536 {print "<2en> " $0}' > $BPE_DATA/test.bpe.${lang}.2
    cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=2537 && NR <=3730 {print "<2ja> " $0}' > $BPE_DATA/test.bpe.${lang}.3
    cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=3731 && NR <=4924 {print "<2en> " $0}' > $BPE_DATA/test.bpe.${lang}.4
    # python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/test.bpe.${lang}.1 $BPE_DATA/test.bpe.${lang}.2 $BPE_DATA/test.bpe.${lang}.3 $BPE_DATA/test.bpe.${lang}.4  -o $TAGGED_DATA/test.${lang}
    python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/test.bpe.${lang}.1 $BPE_DATA/test.bpe.${lang}.4 -o $TAGGED_DATA/test.${lang}
done

for lang in tgt; do
    cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=1 && NR <=133317 {print  $0}' > $BPE_DATA/train.bpe.${lang}.1
    cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=133318 && NR <=266634 {print  $0}' > $BPE_DATA/train.bpe.${lang}.2
    cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=266635 && NR <=489742 {print  $0}' > $BPE_DATA/train.bpe.${lang}.3
    cat $BPE_DATA/train.bpe.${lang} | awk 'NR>=489743 && NR <=712850 {print  $0}' > $BPE_DATA/train.bpe.${lang}.4
    # python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/train.bpe.${lang}.1 $BPE_DATA/train.bpe.${lang}.2 $BPE_DATA/train.bpe.${lang}.3 $BPE_DATA/train.bpe.${lang}.4 -o $TAGGED_DATA/train.${lang}
    python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/train.bpe.${lang}.1 $BPE_DATA/train.bpe.${lang}.4 -o $TAGGED_DATA/train.${lang}

    ## validation
    cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=1 && NR <=1553 {print  $0}' > $BPE_DATA/valid.bpe.${lang}.1
    cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=1554 && NR <=3106 {print  $0}' > $BPE_DATA/valid.bpe.${lang}.2
    cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=3107 && NR <=3977 {print  $0}' > $BPE_DATA/valid.bpe.${lang}.3
    cat $BPE_DATA/valid.bpe.${lang} | awk 'NR>=3978 && NR <=4848 {print  $0}' > $BPE_DATA/valid.bpe.${lang}.4
    # python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/valid.bpe.${lang}.1 $BPE_DATA/valid.bpe.${lang}.2 $BPE_DATA/valid.bpe.${lang}.3 $BPE_DATA/valid.bpe.${lang}.4 -o $TAGGED_DATA/valid.${lang}
    python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/valid.bpe.${lang}.1 $BPE_DATA/valid.bpe.${lang}.4 -o $TAGGED_DATA/valid.${lang}

    ## test
    cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=1 && NR <=1268 {print  $0}' > $BPE_DATA/test.bpe.${lang}.1
    cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=1269 && NR <=2536 {print  $0}' > $BPE_DATA/test.bpe.${lang}.2
    cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=2537 && NR <=3730 {print  $0}' > $BPE_DATA/test.bpe.${lang}.3
    cat $BPE_DATA/test.bpe.${lang} | awk 'NR>=3731 && NR <=4924 {print  $0}' > $BPE_DATA/test.bpe.${lang}.4
    # python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/test.bpe.${lang}.1 $BPE_DATA/test.bpe.${lang}.2 $BPE_DATA/test.bpe.${lang}.3 $BPE_DATA/test.bpe.${lang}.4 -o $TAGGED_DATA/test.${lang}
    python3.6 $EXPDIR/preprocess/merge_file.py -i $BPE_DATA/test.bpe.${lang}.1 $BPE_DATA/test.bpe.${lang}.4 -o $TAGGED_DATA/test.${lang}
done

fairseq-preprocess -s src -t tgt \
			--destdir $BIN_DATA \
			--trainpref $TAGGED_DATA/train \
			--validpref $TAGGED_DATA/valid \
			--testpref $TAGGED_DATA/test \
            --joined-dictionary \
			--workers 32 \
            2>&1 | tee $EXPDIR/logs/preprocess