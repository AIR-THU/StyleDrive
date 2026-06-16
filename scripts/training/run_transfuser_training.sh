TRAIN_TEST_SPLIT=styletrain

CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-0} python $NAVSIM_DEVKIT_ROOT/navsim/planning/script/run_training.py \
        trainer.params.strategy=auto \
        agent=transfuser_agent \
        experiment_name=training_transfuser_agent  \
        train_test_split=$TRAIN_TEST_SPLIT  \
        split=trainval   \
        trainer.params.max_epochs=100 \
        cache_path="${NAVSIM_EXP_ROOT}/training_cache/" \
        use_cache_without_dataset=True  \
        force_cache_computation=False