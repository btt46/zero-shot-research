export env LC_ALL=en_US.UTF-8

HOME=/home/tbui
EXPDIR=$PWD

src=$1
tgt=$2

SCRIPTS=${HOME}/mosesdecoder/scripts
TOKENIZER=$SCRIPTS/tokenizer/tokenizer.perl
CLEAN=$SCRIPTS/training/clean-corpus-n.perl
TRUECASER_TRAIN=$SCRIPTS/recaser/train-truecaser.perl
TRUECASER=$SCRIPTS/recaser/truecase.perl
BPE_TOKENS=12000

DATASET=$PWD/data/evaluation
DATASET_NAME="valid test"
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
    for lang in $src $tgt; do
        python3.6 ${EXPDIR}/preprocess/normalize.py ${DATASET}/${set}.${lang} \
                                                ${NORMALIZED_DATA}/${set}.${lang}
    done
done

# Tokenization
echo "=> Tokenizing..."
for set in $DATASET_NAME; do

    python3.6 ${EXPDIR}/preprocess/tokenize-vi.py ${NORMALIZED_DATA}/${set}.vi ${TOKENIZED_DATA}/${set}.vi
done

# Truecaser
echo "=> Truecasing..."
for set in $DATASET_NAME; do
    $TRUECASER --model $EXPDIR/data/tmp/truecase.model.vi < ${TOKENIZED_DATA}/${set}.vi > ${TRUECASED_DATA}/${set}.vi
    mecab -Owakati ${NORMALIZED_DATA}/${set}.ja > ${TRUECASED_DATA}/${set}.ja 
done

echo "=> Subword..."
for set in $DATASET_NAME; do
    for lang in $src $tgt; do
        subword-nmt apply-bpe -c $EXPDIR/data/tmp/bpe.${BPE_TOKENS}.model < ${TRUECASED_DATA}/${set}.${lang} > $BPE_DATA/${set}.${lang}
    done
done

# adding tags
## train data
# echo "=> Adding tags"

for set in $DATASET_NAME; do
    # cat $BPE_DATA/${set}.${src} | awk -v tag="<2${tgt}>" '{print tag " " $0}' > $TAGGED_DATA/${set}.${src}
    cat $BPE_DATA/${set}.${src} | awk -v tag="<2${tgt}>" '{print $0}' > $TAGGED_DATA/${set}.${src}
done





