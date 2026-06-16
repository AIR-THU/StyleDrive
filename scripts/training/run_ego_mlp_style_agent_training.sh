TRAIN_TEST_SPLIT=styletrain

CUDA_VISIBLE_DEVICES=${CUDA_VISIBLE_DEVICES:-0} python $NAVSIM_DEVKIT_ROOT/navsim/planning/script/run_training.py \
        trainer.params.strategy=auto \
        experiment_name=training_ego_mlp_style_agent \
        trainer.params.max_epochs=50 \
        train_test_split=$TRAIN_TEST_SPLIT \
        agent=ego_status_mlp_style_agent