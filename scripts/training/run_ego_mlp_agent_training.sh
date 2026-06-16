TRAIN_TEST_SPLIT=styletrain

CUDA_VISIBLE_DEVICES=0 python $NAVSIM_DEVKIT_ROOT/navsim/planning/script/run_training.py \
        experiment_name=training_ego_mlp_agent \
        trainer.params.max_epochs=50 \
        train_test_split=$TRAIN_TEST_SPLIT \
        cache_path="${NAVSIM_EXP_ROOT}/training_cache/" \
        use_cache_without_dataset=True  \
        force_cache_computation=False