#!/bin/bash
set -e
source path.sh

gpus=0,1,2,3
stage=0
stop_stage=100
conf_path=conf/deepspeech2.yaml    #conf/deepspeech2.yaml or conf/deepspeech2_online.yaml
decode_conf_path=conf/tuning/decode.yaml
avg_num=1
model_type=offline    # offline or online
audio_file=data/demo_01_03.wav

source ${MAIN_ROOT}/utils/parse_options.sh || exit 1;

avg_ckpt=avg_${avg_num}
ckpt=$(basename ${conf_path} | awk -F'.' '{print $1}')
echo "checkpoint name ${ckpt}"


if [ ${stage} -le 0 ] && [ ${stop_stage} -ge 0 ]; then
    # prepare data
    bash ./local/data.sh || exit -1
fi

if [ ${stage} -le 1 ] && [ ${stop_stage} -ge 1 ]; then
    # train model, all `ckpt` under `exp` dir
    CUDA_VISIBLE_DEVICES=${gpus} ./local/train.sh ${conf_path}  ${ckpt} ${model_type}
fi

if [ ${stage} -le 2 ] && [ ${stop_stage} -ge 2 ]; then
    # avg n best model
    avg.sh best exp/${ckpt}/checkpoints ${avg_num}
fi

if [ ${stage} -le 3 ] && [ ${stop_stage} -ge 3 ]; then
    # test ckpt avg_n
    CUDA_VISIBLE_DEVICES=0 ./local/test.sh ${conf_path} ${decode_conf_path} exp/${ckpt}/checkpoints/${avg_ckpt} ${model_type}|| exit -1
fi

if [ ${stage} -le 4 ] && [ ${stop_stage} -ge 4 ]; then
    # export ckpt avg_n
    CUDA_VISIBLE_DEVICES=0 ./local/export.sh ${conf_path} exp/${ckpt}/checkpoints/${avg_ckpt} exp/${ckpt}/checkpoints/${avg_ckpt}.jit ${model_type}
fi

if [ ${stage} -le 5 ] && [ ${stop_stage} -ge 5 ]; then
    # test export ckpt avg_n
    CUDA_VISIBLE_DEVICES=0 ./local/test_export.sh ${conf_path} ${decode_conf_path} exp/${ckpt}/checkpoints/${avg_ckpt}.jit ${model_type}|| exit -1
fi

# Optionally, you can add LM and test it with runtime.
if [ ${stage} -le 6 ] && [ ${stop_stage} -ge 6 ]; then
    # test a single .wav file
    CUDA_VISIBLE_DEVICES=0 ./local/test_wav.sh ${conf_path} ${decode_conf_path} exp/${ckpt}/checkpoints/${avg_ckpt} ${model_type} ${audio_file} || exit -1
fi
