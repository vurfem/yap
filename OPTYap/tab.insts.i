/**********************************************************************
                                                               
                       The OPTYap Prolog system                
  OPTYap extends the Yap Prolog system to support or-parallel tabling
                                                               
  Copyright:   R. Rocha and NCC - University of Porto, Portugal
  File:        tab.insts.i
  version:     $Id: tab.insts.i,v 1.26 2008-05-23 18:28:58 ricroc Exp $   
                                                                     
**********************************************************************/

/* ------------------------------------------------ **
**      Tabling instructions: auxiliary macros      **
** ------------------------------------------------ */

#ifdef LOW_LEVEL_TRACER
#define store_low_level_trace_info(CP, TAB_ENT)  CP->cp_pred_entry = TabEnt_pe(TAB_ENT)
#else
#define store_low_level_trace_info(CP, TAB_ENT)
#endif /* LOW_LEVEL_TRACER */


#ifdef TABLING_ERRORS
#define TABLING_ERRORS_check_stack                                                     \
        if (Unsigned(H) + 1024 > Unsigned(B))                                          \
	  TABLING_ERROR_MESSAGE("H + 1024 > B (check_stack)");                         \
        if (Unsigned(H_FZ) + 1024 > Unsigned(B))                                       \
	  TABLING_ERROR_MESSAGE("H_FZ + 1024 > B (check_stack)")
#define TABLING_ERRORS_consume_answer_and_procceed                                     \
        if (IS_BATCHED_GEN_CP(B))                                                      \
	  TABLING_ERROR_MESSAGE("IS_BATCHED_GEN_CP(B) (consume_answer_and_procceed)")
#else
#define TABLING_ERRORS_check_stack
#define TABLING_ERRORS_consume_answer_and_procceed
#endif /* TABLING_ERRORS */


#define store_generator_node(TAB_ENT, SG_FR, ARITY, AP)               \
        { register CELL *pt_args;                                     \
          register choiceptr gcp;                                     \
          /* store args */                                            \
          pt_args = XREGS + (ARITY);                                  \
	        while (pt_args > XREGS) {                                   \
            register CELL aux_arg = pt_args[0];                       \
            --YENV;                                                   \
            --pt_args;                                                \
            *YENV = aux_arg;                                          \
	        }                                                           \
          /* initialize gcp and adjust subgoal frame field */         \
          YENV = (CELL *) (GEN_CP(YENV) - 1);                         \
          gcp = NORM_CP(YENV);                                        \
          dprintf("New generator choice point: %d\n", gcp);           \
          SgFr_choice_point(SG_FR) = gcp;                             \
          /* store generator choice point */                          \
          HBREG = H;                                                  \
          store_yaam_reg_cpdepth(gcp);                                \
          gcp->cp_tr = TR;                                            \
          gcp->cp_ap = (yamop *)(AP);                                 \
          gcp->cp_h  = H;                                             \
          gcp->cp_b  = B;                                             \
          gcp->cp_env = ENV;                                          \
          gcp->cp_cp = CPREG;                                         \
	        if (IsMode_Local(TabEnt_mode(TAB_ENT))) {                   \
            /* go local */                                            \
            register dep_fr_ptr new_dep_fr;                           \
            /* adjust freeze registers */                             \
            H_FZ = H;                                                 \
            B_FZ = gcp;                                               \
            TR_FZ = TR;                                               \
            /* store dependency frame */                              \
            new_dependency_frame(new_dep_fr, TRUE, LOCAL_top_or_fr,   \
                                 gcp, gcp, SG_FR, LOCAL_top_dep_fr);  \
            LOCAL_top_dep_fr = new_dep_fr;                            \
            GEN_CP(gcp)->cp_dep_fr = LOCAL_top_dep_fr;                \
          } else {                                                    \
            /* go batched */                                          \
            GEN_CP(gcp)->cp_dep_fr = NULL;                            \
          }                                                           \
          GEN_CP(gcp)->cp_sg_fr = SG_FR;                              \
          store_low_level_trace_info(GEN_CP(gcp), TAB_ENT);           \
          set_cut((CELL *)gcp, B);                                    \
          B = gcp;                                                    \
          YAPOR_SET_LOAD(B);                                          \
          SET_BB(B);                                                  \
          TABLING_ERRORS_check_stack;                                 \
        }


#ifdef DETERMINISTIC_TABLING
#define store_deterministic_generator_node(TAB_ENT, SG_FR)            \
        { register choiceptr gcp;                                     \
          /* initialize gcp and adjust subgoal frame field */         \
          YENV = (CELL *) (DET_GEN_CP(YENV) - 1);                     \
	        gcp = NORM_CP(YENV);                                        \
          SgFr_choice_point(SG_FR) = gcp;                                   \
          /* store deterministic generator choice point */            \
          HBREG = H;                                                  \
          store_yaam_reg_cpdepth(gcp);                                \
          gcp->cp_ap = COMPLETION;                                    \
          gcp->cp_b  = B;                                             \
          gcp->cp_tr = TR;           	  	                            \
          gcp->cp_h = H;                                              \
	        DET_GEN_CP(gcp)->cp_sg_fr = SG_FR;                          \
          store_low_level_trace_info(DET_GEN_CP(gcp), TAB_ENT);       \
          set_cut((CELL *)gcp, B);                                    \
          B = gcp;                                                    \
          YAPOR_SET_LOAD(B);                                          \
          SET_BB(B);                                                  \
          TABLING_ERRORS_check_stack;                                 \
	}
#endif /* DETERMINISTIC_TABLING */


#define restore_generator_node(ARITY, AP)               \
        { register CELL *pt_args, *x_args;              \
          register choiceptr gcp = B;                   \
          /* restore generator choice point */          \
          H = HBREG = PROTECT_FROZEN_H(gcp);            \
          restore_yaam_reg_cpdepth(gcp);                \
          CPREG = gcp->cp_cp;                           \
          ENV = gcp->cp_env;                            \
          YAPOR_update_alternative(PREG, (yamop *) AP)  \
          gcp->cp_ap = (yamop *) AP;                    \
          /* restore args */                            \
          pt_args = (CELL *)(GEN_CP(gcp) + 1) + ARITY;  \
          x_args = XREGS + 1 + ARITY;                   \
          while (x_args > XREGS + 1) {                  \
            register CELL x = pt_args[-1];              \
            --x_args;                                   \
            --pt_args;                                  \
            *x_args = x;                                \
	        }                                             \
        }


#define pop_generator_node(ARITY)               \
        { register CELL *pt_args, *x_args;      \
          register choiceptr gcp = B;           \
          /* pop generator choice point */      \
          H = PROTECT_FROZEN_H(gcp);            \
          pop_yaam_reg_cpdepth(gcp);            \
          CPREG = gcp->cp_cp;                   \
          ENV = gcp->cp_env;                    \
          TR = gcp->cp_tr;                      \
          B = gcp->cp_b;                        \
          HBREG = PROTECT_FROZEN_H(B);		      \
          /* pop args */                        \
          x_args = XREGS + 1 ;                  \
          pt_args = (CELL *)(GEN_CP(gcp) + 1);  \
	  while (x_args < XREGS + 1 + ARITY) {        \
            register CELL x = pt_args[0];       \
            pt_args++;                          \
            x_args++;                           \
            x_args[-1] = x;                     \
          }                                     \
          YENV = pt_args;		    	\
          SET_BB(PROTECT_FROZEN_B(B));          \
        }


#define store_consumer_node(TAB_ENT, SG_FR, LEADER_CP, DEP_ON_STACK)       \
        { register choiceptr ccp;                                          \
          register dep_fr_ptr new_dep_fr;                                  \
	        /* initialize ccp */                                             \
          YENV = (CELL *) (CONS_CP(YENV) - 1);                             \
          ccp = NORM_CP(YENV);                                             \
          /* adjust freeze registers */                                    \
          H_FZ = H;                                                        \
          B_FZ = ccp;                    	                                 \
          TR_FZ = TR;                                                      \
          /* store dependency frame */                                     \
          new_dependency_frame(new_dep_fr, DEP_ON_STACK, LOCAL_top_or_fr,  \
                               LEADER_CP, ccp, SG_FR, LOCAL_top_dep_fr);   \
          LOCAL_top_dep_fr = new_dep_fr;                                   \
          /* store consumer choice point */                                \
          HBREG = H;                                                       \
          store_yaam_reg_cpdepth(ccp);                                     \
          ccp->cp_tr = TR;         	                                       \
          ccp->cp_ap = ANSWER_RESOLUTION;                                  \
          ccp->cp_h  = H;                                                  \
          ccp->cp_b  = B;                                                  \
          ccp->cp_env= ENV;                                                \
          ccp->cp_cp = CPREG;                                              \
          CONS_CP(ccp)->cp_dep_fr = LOCAL_top_dep_fr;                      \
          store_low_level_trace_info(CONS_CP(ccp), TAB_ENT);               \
          /* set_cut((CELL *)ccp, B); --> no effect */                     \
          B = ccp;                                                         \
          YAPOR_SET_LOAD(B);                                               \
          SET_BB(B);                                                       \
          TABLING_ERRORS_check_stack;                                      \
          dprintf("New consumer cp %d\n", (int)B);                         \
        }
        
#define CONSUME_ANSWER(ANS_NODE, ANSWER_TMPLT, SG_FR)                       \
        switch(SgFr_type(SG_FR)) {                                          \
          case VARIANT_PRODUCER_SFT:                                        \
          case SUBSUMPTIVE_PRODUCER_SFT:                                    \
            CONSUME_VARIANT_ANSWER(ANS_NODE, ANSWER_TMPLT);                 \
            break;                                                          \
          case SUBSUMED_CONSUMER_SFT:                                       \
          case GROUND_CONSUMER_SFT:                                         \
            CONSUME_SUBSUMPTIVE_ANSWER(ANS_NODE, ANSWER_TMPLT);             \
            break;                                                          \
          case GROUND_PRODUCER_SFT:                                         \
            CONSUME_GROUND_ANSWER(ANS_NODE, ANSWER_TMPLT, SG_FR);           \
            break;                                                          \
          }

#define consume_answer_and_procceed(DEP_FR, ANSWER)       \
        { CELL *subs_ptr;                                 \
          dprintf("Consume_answer_and_proceed\n");        \
          /* restore consumer choice point */             \
          H = HBREG = PROTECT_FROZEN_H(B);                \
          restore_yaam_reg_cpdepth(B);                    \
          CPREG = B->cp_cp;                               \
          ENV = B->cp_env;                                \
          /* set_cut(YENV, B->cp_b); --> no effect */     \
          PREG = (yamop *) CPREG;                         \
          PREFETCH_OP(PREG);                              \
          /* load answer from table to global stack */    \
          if (B == DepFr_leader_cp(DEP_FR)) {             \
            /*  B is a generator-consumer node  */        \
            /* never here if batched scheduling */        \
            TABLING_ERRORS_consume_answer_and_procceed;   \
            subs_ptr = (CELL *) (GEN_CP(B) + 1);          \
            subs_ptr += SgFr_arity(GEN_CP(B)->cp_sg_fr);  \
	        } else {                                        \
            subs_ptr = CONSUMER_ANSWER_TEMPLATE(DEP_FR);  \
	        }                                               \
          CONSUME_ANSWER(ANSWER, subs_ptr, DepFr_sg_fr(DEP_FR));  \
          /* procceed */                                  \
          YENV = ENV;                                     \
          GONext();                                       \
        }


#define store_loader_node(TAB_ENT, ANSWER, LOAD_INSTR)        \
        { register choiceptr lcp;                             \
	        /* initialize lcp */                                \
          lcp = NORM_CP(LOAD_CP(YENV) - 1);                   \
          /* store loader choice point */                     \
          HBREG = H;                                          \
          store_yaam_reg_cpdepth(lcp);                        \
          lcp->cp_tr = TR;         	                          \
          lcp->cp_ap = LOAD_INSTR;                            \
          lcp->cp_h  = H;                                     \
          lcp->cp_b  = B;                                     \
          lcp->cp_env= ENV;                                   \
          lcp->cp_cp = CPREG;                                 \
          LOAD_CP(lcp)->cp_last_answer = ANSWER;              \
          store_low_level_trace_info(LOAD_CP(lcp), TAB_ENT);  \
          /* set_cut((CELL *)lcp, B); --> no effect */        \
          B = lcp;                                            \
          YAPOR_SET_LOAD(B);                                  \
          SET_BB(B);                                          \
          TABLING_ERRORS_check_stack;                         \
        }


#define restore_loader_node(ANSWER)             \
        { H = HBREG = PROTECT_FROZEN_H(B);      \
          restore_yaam_reg_cpdepth(B);          \
          CPREG = B->cp_cp;                     \
          ENV = B->cp_env;                      \
          LOAD_CP(B)->cp_last_answer = ANSWER;  \
          SET_BB(PROTECT_FROZEN_B(B))           \
        }


#define pop_loader_node()               \
        { H = PROTECT_FROZEN_H(B);      \
          pop_yaam_reg_cpdepth(B);      \
	        CPREG = B->cp_cp;             \
          TABLING_close_alt(B);	        \
          ENV = B->cp_env;              \
	        B = B->cp_b;	                \
          HBREG = PROTECT_FROZEN_H(B);  \
          SET_BB(PROTECT_FROZEN_B(B))   \
        }


#ifdef DEPTH_LIMIT
#define allocate_environment()        \
        YENV[E_CP] = (CELL) CPREG;    \
        YENV[E_E] = (CELL) ENV;       \
        YENV[E_B] = (CELL) B;         \
        YENV[E_DEPTH] = (CELL)DEPTH;  \
        ENV = YENV
#else
#define allocate_environment()        \
        YENV[E_CP] = (CELL) CPREG;    \
        YENV[E_E] = (CELL) ENV;       \
        YENV[E_B] = (CELL) B;         \
        ENV = YENV
#endif /* DEPTH_LIMIT */

#ifdef TABLING_CALL_SUBSUMPTION
#define init_consumer_subgoal_frame(SG_FR)  \
        if(SgFr_state(sg_fr) < evaluating) {  \
          switch(SgFr_type(sg_fr)) {  \
            case SUBSUMED_CONSUMER_SFT: \
              init_sub_consumer_subgoal_frame((subcons_fr_ptr)sg_fr); \
              break;  \
            case GROUND_CONSUMER_SFT: \
              init_ground_consumer_subgoal_frame((grounded_sf_ptr)sg_fr); \
              break;  \
          } \
        }
#else
#define init_consumer_subgoal_frame(SG_FR) /* do nothing */
#endif /* TABLING_CALL_SUBSUMPTION */

#define ensure_subgoal_is_compiled(SG_FR) \
        if (SgFr_state(SG_FR) < compiled) \
  	      update_answer_trie(SG_FR)
  	      
#define check_no_answers(SG_FR) \
        if (SgFr_has_no_answers(SG_FR)) { \
    	      /* no answers --> fail */ \
    	      UNLOCK(SgFr_lock(SG_FR)); \
    	      goto fail;  \
    	    }
    	    
#define check_yes_answer_no_unlock(SG_FR)   \
        if (SgFr_has_yes_answer(SG_FR)) {   \
          /* yes answer --> procceed */     \
          procceed_yes_answer();            \
        }
        
#define procceed_yes_answer()               \
        PREG = (yamop *) CPREG;             \
        PREFETCH_OP(PREG);                  \
        YENV = ENV;                         \
        GONext()
    	    
#define check_yes_answer(SG_FR)             \
        if (SgFr_has_yes_answer(SG_FR)) {   \
    	    /* yes answer --> procceed */     \
    	    UNLOCK(SgFr_lock(SG_FR));         \
          procceed_yes_answer();            \
        }
        
#ifdef LIMIT_TABLING
#define limit_tabling_do_remove_sf(SG_FR)   \
        SgFr_state(SG_FR)++;  /* complete --> complete_in_use : compiled --> compiled_in_use */ \
	      remove_from_global_sg_fr_list(SG_FR); \
	      TRAIL_FRAME(SG_FR)
	      
#define limit_tabling_remove_sf(SG_FR)      \
        if (SgFr_state(SG_FR) == complete || SgFr_state(SG_FR) == compiled) { \
          limit_tabling_do_remove_sf(SG_FR);                                  \
        }
#else
#define limit_tabling_do_remove_sf(SG_FR) /* nothing */
#define limit_tabling_remove_sf(SG_FR) /* nothing */
#endif /* LIMIT_TABLING */

#define load_continuation_and_answer(SG_FR) \
        continuation_ptr cont = SgFr_first_answer(SG_FR); \
        ans_node_ptr ans_node = continuation_answer(cont)
        
#define consume_answer_leaf(ANSWER_NODE, ANSWER_TEMPLATE, CONSUME_FN)   \
        PREG = (yamop *) CPREG;                                         \
        PREFETCH_OP(PREG);                                              \
        CONSUME_FN(ANSWER_NODE, ANSWER_TEMPLATE);                       \
        YENV = ENV;                                                     \
        GONext()
        
#define load_run_answers(TAB_ENT, LOAD_INSTR, CONSUME_FN, ANSWER_TEMPLATE) \
        if(continuation_has_next(cont)) \
          store_loader_node(TAB_ENT, cont, LOAD_INSTR); \
        consume_answer_leaf(ans_node, ANSWER_TEMPLATE, CONSUME_FN)

#define load_answers_from_sf(SG_FR, TAB_ENT, CONSUME_FN, LOAD_INSTR, ANSWER_TEMPLATE)  \
        load_continuation_and_answer(SG_FR);                          \
	      UNLOCK(SgFr_lock(SG_FR));                                     \
	      load_run_answers(TAB_ENT, LOAD_INSTR, CONSUME_FN, ANSWER_TEMPLATE)
        
#define load_answers_from_sf_no_unlock(SG_FR, TAB_ENT, CONSUME_FN, LOAD_INSTR, ANSWER_TEMPLATE) \
        load_continuation_and_answer(SG_FR);              \
        load_run_answers(TAB_ENT, LOAD_INSTR, CONSUME_FN, ANSWER_TEMPLATE)
        
#define load_variant_answers_from_sf(SG_FR, TAB_ENT, ANSWER_TEMPLATE)                  \
        load_answers_from_sf(SG_FR, TAB_ENT, CONSUME_VARIANT_ANSWER, LOAD_ANSWER, ANSWER_TEMPLATE)

#define load_subsumptive_answers_from_sf(SG_FR, TAB_ENT, ANSWER_TEMPLATE)              \
        load_answers_from_sf(SG_FR, TAB_ENT, CONSUME_SUBSUMPTIVE_ANSWER, LOAD_CONS_ANSWER, ANSWER_TEMPLATE)
        
#ifdef GLOBAL_TRIE
#define exec_compiled_trie(TRIE)  \
        PREG = (yamop *)TrNode_child(TRIE); \
        PREFETCH_OP(PREG);    \
        *--YENV = 0;          \
        GONext()
#else
#define exec_compiled_trie(TRIE)  \
        PREG = (yamop *) TrNode_child(TRIE);  \
  	    PREFETCH_OP(PREG);  \
  	    /* vars_arity */    \
  	    *--YENV = 0; \
  	    /* heap_arity */ \
        *--YENV = 0;    \
        GONext()
#endif /* GLOBAL_TRIE */

#define exec_subgoal_compiled_trie(SG_FR)           \
        UNLOCK(SgFr_lock(SG_FR));                   \
        exec_compiled_trie(SgFr_answer_trie(SG_FR))

#ifdef TABLING_CALL_SUBSUMPTION

#define compute_subsumptive_consumer_answer_list(SG_FR) \
      if(SgFr_state(SG_FR) < complete) {      \
        build_next_subsumptive_consumer_return_list((subcons_fr_ptr)(SG_FR)); \
        SgFr_state(SG_FR) = complete; \
      }
      
#define compute_ground_consumer_answer_list(SG_FR)                        \
      if(SgFr_state(SG_FR) < complete) {                                  \
        build_next_ground_consumer_return_list((grounded_sf_ptr)(SG_FR)); \
        SgFr_state(SG_FR) = complete;                                     \
      }
      
#define set_subsumptive_producer(SG_FR)                           \
      if(SgFr_state(SG_FR) < compiled)                            \
        SgFr_state(SG_FR) = compiled;                             \
      UNLOCK(SgFr_lock(SG_FR));                                   \
      SG_FR = (sg_fr_ptr)SgFr_producer((subcons_fr_ptr)(SG_FR));  \
      LOCK(SgFr_lock(SG_FR))
      
#define exec_ground_trie(TAB_ENT)                                       \
      if(TabEnt_arity(TAB_ENT) == 0) {                                  \
        if(TabEnt_ground_yes(TAB_ENT)) {                                \
          procceed_yes_answer();                                        \
        } else {                                                        \
          goto fail;                                                    \
        }                                                               \
      } else {                                                          \
        exec_compiled_trie((ans_node_ptr)TabEnt_ground_trie(TAB_ENT));  \
      }
      
#define check_ground_pre_stored_answers(SG_FR, TAB_ENT, GROUND_SG)  \
    if(TabEnt_ground_time_stamp(TAB_ENT) > 0) {                     \
      grounded_sf_ptr ground_sg = (grounded_sf_ptr)(SG_FR);         \
                                                                    \
      /* retrieve more answers */                                   \
      build_next_ground_producer_return_list(GROUND_SG);            \
                                                                    \
      continuation_ptr cont = SgFr_first_answer(GROUND_SG);         \
                                                                    \
      if(cont) {                                                    \
        ans_node_ptr ans_node = continuation_answer(cont);          \
        CELL *answer_template = (CELL *)(GEN_CP(B) + 1) + SgFr_arity(SG_FR);  \
                                                                    \
        SgFr_try_answer(GROUND_SG) = cont;                          \
                                                                    \
        B->cp_ap = TRY_GROUND_ANSWER;                               \
        PREG = (yamop *)CPREG;                                      \
        PREFETCH_OP(PREG);                                          \
        CONSUME_GROUND_ANSWER(ans_node, answer_template, GROUND_SG);\
        YENV = ENV;                                                 \
        GONext();                                                   \
      }                                                             \
    }
    
#define check_ground_pending_subgoals(SG_FR, TAB_ENT, GROUND_SG)    \
    { ALNptr list = collect_specific_generator_goals(TAB_ENT,       \
      TabEnt_arity(TAB_ENT), SgFr_answer_template(GROUND_SG));      \
      process_pending_subgoal_list(list, GROUND_SG);                \
      increment_sugoal_path(SG_FR);                                 \
    }

#define check_ground_generator(SG_FR, TAB_ENT)                      \
    if(SgFr_is_ground_producer(SG_FR)) {                            \
      grounded_sf_ptr ground_sg = (grounded_sf_ptr)(SG_FR);         \
      check_ground_pending_subgoals(SG_FR, TAB_ENT, ground_sg);     \
      check_ground_pre_stored_answers(SG_FR, TAB_ENT, ground_sg);   \
    }
          

/* Consume subsuming answer ANS_NODE using ANS_TMPLT
 * as the pointer to the answer template.
 * the size of the answer template is calculated and
 * consume_subsumptive_answer is called to do the real work
 */
#define CONSUME_SUBSUMPTIVE_ANSWER(ANS_NODE, ANS_TMPLT) {                     \
  int arity = (int)*(ANS_TMPLT);                                              \
  CELL *sub_answer_template = (ANS_TMPLT) + arity;                            \
  consume_subsumptive_answer((BTNptr)(ANS_NODE), arity, sub_answer_template); \
}

#define CONSUME_GROUND_ANSWER(ANS_NODE, ANS_TMPLT, SG_FR) \
  if(SgFr_is_most_general((grounded_sf_ptr)(SG_FR))) {    \
    CONSUME_VARIANT_ANSWER(ANS_NODE, ANS_TMPLT);          \
  } else {                                                \
    CONSUME_SUBSUMPTIVE_ANSWER(ANS_NODE, ANS_TMPLT);      \
  }
  
#define consume_next_ground_answer(CONT, SG_FR)                 \
  CELL *answer_template = CONSUMER_NODE_ANSWER_TEMPLATE(B);  \
  ans_node_ptr ans_node = continuation_answer(CONT);            \
                                                                \
  H = HBREG = PROTECT_FROZEN_H(B);                              \
  restore_yaam_reg_cpdepth(B);                                  \
  CPREG = B->cp_cp;                                             \
  ENV = B->cp_env;                                              \
                                                                \
  SgFr_try_answer(sg_fr) = CONT;                                \
                                                                \
  PREG = (yamop *) CPREG;                                       \
  PREFETCH_OP(PREG);                                            \
  CONSUME_SUBSUMPTIVE_ANSWER(ans_node, answer_template);        \
  YENV = ENV;                                                   \
  GONext()

#else

#define CONSUME_SUBSUMPTIVE_ANSWER(ANS_NODE, ANS_TMPLT) Yap_Error(INTERNAL_ERROR, TermNil, "tabling by call subsumption not supported")

#endif /* TABLING_CALL_SUBSUMPTION */

/* Consume a variant answer ANS_NODE using ANS_TMPLT
 * as the pointer to the answer template.
 */
#define CONSUME_VARIANT_ANSWER(ANS_NODE, ANS_TMPLT) { \
    int arity = (int)*(ANS_TMPLT);  \
    consume_variant_answer(ANS_NODE, arity, (ANS_TMPLT)+1); \
  }

/* ------------------------------ **
**      Tabling instructions      **
** ------------------------------ */  

#ifdef TABLING_INNER_CUTS
  Op(clause_with_cut, e)
    if (LOCAL_pruning_scope) {
      if (YOUNGER_CP(LOCAL_pruning_scope, B))
        LOCAL_pruning_scope = B;
    } else {
      LOCAL_pruning_scope = B;
      PUT_IN_PRUNING(worker_id);
    }
    PREG = NEXTOP(PREG, e);
    GONext();
  ENDOp();
#endif /* TABLING_INNER_CUTS */

  PBOp(table_load_cons_answer, Otapl)
#ifdef TABLING_CALL_SUBSUMPTION
    CELL *ans_tmplt;
    ans_node_ptr ans_node;
    continuation_ptr next;
    
    ans_tmplt = (CELL *) (LOAD_CP(B) + 1);
    
    next = continuation_next(LOAD_CP(B)->cp_last_answer);
    ans_node = continuation_answer(next);
    
    if(continuation_has_next(next)) {
      restore_loader_node(next);
    } else {
      pop_loader_node();
    }
    
    consume_answer_leaf(ans_node, ans_tmplt, CONSUME_SUBSUMPTIVE_ANSWER);
#else
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (table_load_cons_answer)");
#endif
  ENDPBOp();

  PBOp(table_load_answer, Otapl)
    CELL *ans_tmplt;
    ans_node_ptr ans_node;
    continuation_ptr next;
    
    dprintf("===> TABLE_LOAD_ANSWER\n");

#ifdef YAPOR
    if (SCH_top_shared_cp(B)) {
#if 0
      PROBLEM: cp_last_answer field is local to the cp!
               -> we need a shared data structure to avoid redundant computations!
      UNLOCK_OR_FRAME(LOCAL_top_or_fr);
#else
      fprintf(stderr,"PROBLEM: cp_last_answer field is local to the cp!\n");
      exit(1);
#endif
    }
#endif /* YAPOR */

    ans_tmplt = (CELL *) (LOAD_CP(B) + 1);
    
    next = continuation_next(LOAD_CP(B)->cp_last_answer);
    ans_node = continuation_answer(next);
    
    if(continuation_has_next(next)) {
      restore_loader_node(next);
    } else {
      pop_loader_node();
    }
    
    consume_answer_leaf(ans_node, ans_tmplt, CONSUME_VARIANT_ANSWER);
  ENDPBOp();
  
  PBOp(table_run_completed, Otapl)
#ifdef TABLING_CALL_SUBSUMPTION
    dprintf("===> TABLE_RUN_COMPLETED\n");
    
    /* cp_dep_fr points to the subgoal frame */
    grounded_sf_ptr sg_fr = (grounded_sf_ptr)CONS_CP(B)->cp_dep_fr;
    tab_ent_ptr tab_ent = SgFr_tab_ent(sg_fr);

    if(SgFr_state(SgFr_producer(sg_fr)) < complete) {
      dprintf("producer not completed!\n");
      build_next_ground_consumer_return_list(sg_fr);
      continuation_ptr next_cont = continuation_next(SgFr_try_answer(sg_fr));
      
      if(next_cont) {
        dprintf("Consuming...\n");
        /* as long we can consume answers we
         * can avoid being a real consumer */
        consume_next_ground_answer(next_cont, sg_fr);
      }
      
      /* no more answers to consume, transform this node
         into a consumer */
      dprintf("Not completed!\n");
      add_dependency_frame(sg_fr, B);
      B->cp_ap = ANSWER_RESOLUTION;
      B = B->cp_b;
      goto fail;
    }
    dprintf("just completed!\n");
    /* producer subgoal just completed */
    mark_ground_consumer_as_completed(sg_fr);
    
    if(TabEnt_is_load(tab_ent)) {
      
      build_next_ground_consumer_return_list(sg_fr);
      continuation_ptr next_cont = continuation_next(SgFr_try_answer(sg_fr));
      
      if(!next_cont) {
        /* fail now */
        B = B->cp_b;
        goto fail;
      }
      
      dprintf("Transform into loader\n");
      
      /* transform this generator/consumer choice point into a loader node */
      LOAD_CP(B)->cp_last_answer = SgFr_try_answer(sg_fr);
      B->cp_ap = LOAD_CONS_ANSWER;
      goto fail;
    } else {
      /* XXX: run compiled code */
    }
    
    printf("CANT BE HERE!!!\n");
    exit(1);
#endif /* TABLING_CALL_SUBSUMPTION */
  ENDPBOp();
  
  PBOp(table_try_answer, Otapl)
    dprintf("===> TABLE_TRY_ANSWER\n");
#ifdef INCOMPLETE_TABLING
    sg_fr_ptr sg_fr;
    ans_node_ptr ans_node = NULL;
    continuation_ptr next_cont;

    sg_fr = GEN_CP(B)->cp_sg_fr;
    next_cont = continuation_next(SgFr_try_answer(sg_fr));
    
    if(next_cont) {
      CELL *subs_ptr = (CELL *) (GEN_CP(B) + 1) + SgFr_arity(sg_fr);

      ans_node = continuation_answer(next_cont);
      H = HBREG = PROTECT_FROZEN_H(B);
      restore_yaam_reg_cpdepth(B);
      CPREG = B->cp_cp;
      ENV = B->cp_env;
      SgFr_try_answer(sg_fr) = next_cont;

#ifdef YAPOR
      if (SCH_top_shared_cp(B))
	      UNLOCK_OR_FRAME(LOCAL_top_or_fr);
#endif /* YAPOR */
      SET_BB(PROTECT_FROZEN_B(B));

      PREG = (yamop *) CPREG;
      PREFETCH_OP(PREG);
      CONSUME_VARIANT_ANSWER(ans_node, subs_ptr);
      YENV = ENV;
      GONext();
    } else {
      yamop *code_ap;
      PREG = SgFr_code(sg_fr);
      if (PREG->opc == Yap_opcode(_table_try)) {
	      /* table_try */
	      code_ap = NEXTOP(PREG,Otapl);
	      PREG = PREG->u.Otapl.d;
      } else if (PREG->opc == Yap_opcode(_table_try_single)) {
	      /* table_try_single */
	      code_ap = COMPLETION;
	      PREG = PREG->u.Otapl.d;
      } else {
	      /* table_try_me */
	      code_ap = PREG->u.Otapl.d;
	      PREG = NEXTOP(PREG,Otapl);
      }
      PREFETCH_OP(PREG);
      restore_generator_node(SgFr_arity(sg_fr), code_ap);
      YENV = (CELL *) PROTECT_FROZEN_B(B);
      set_cut(YENV, B->cp_b);
      SET_BB(NORM_CP(YENV));
      allocate_environment();
      GONext();
    }
#else
    PREG = PREG->u.Otapl.d;
    PREFETCH_OP(PREG);
    GONext();    
#endif /* INCOMPLETE_TABLING */
  ENDPBOp();

  PBOp(table_try_ground_answer, Otapl)
  #ifdef TABLING_CALL_SUBSUMPTION
    grounded_sf_ptr sg_fr;
    ans_node_ptr ans_node = NULL;
    continuation_ptr next_cont;
    
    dprintf("===> TABLE_TRY_GROUND_ANSWER\n");
    
    sg_fr = (grounded_sf_ptr)GEN_CP(B)->cp_sg_fr;
    next_cont = continuation_next(SgFr_try_answer(sg_fr));
    
    if(next_cont) {
      CELL *answer_template = (CELL *)(GEN_CP(B) + 1) + SgFr_arity(sg_fr);
      
      ans_node = continuation_answer(next_cont);
      H = HBREG = PROTECT_FROZEN_H(B);
      restore_yaam_reg_cpdepth(B);
      CPREG = B->cp_cp;
      ENV = B->cp_env;
      SgFr_try_answer(sg_fr) = next_cont;
      
      PREG = (yamop *) CPREG;
      PREFETCH_OP(PREG);
      CONSUME_GROUND_ANSWER(ans_node, answer_template, sg_fr);
      YENV = ENV;
      GONext();
    } else {
      yamop *code_ap;
      PREG = SgFr_code(sg_fr);
      if (PREG->opc == Yap_opcode(_table_try)) {
	      /* table_try */
	      code_ap = NEXTOP(PREG,Otapl);
	      PREG = PREG->u.Otapl.d;
      } else if (PREG->opc == Yap_opcode(_table_try_single)) {
	      /* table_try_single */
	      code_ap = COMPLETION;
	      PREG = PREG->u.Otapl.d;
      } else {
	      /* table_try_me */
	      code_ap = PREG->u.Otapl.d;
	      PREG = NEXTOP(PREG,Otapl);
      }
      PREFETCH_OP(PREG);
      restore_generator_node(SgFr_arity(sg_fr), code_ap);
      YENV = (CELL *) PROTECT_FROZEN_B(B);
      set_cut(YENV, B->cp_b);
      SET_BB(NORM_CP(YENV));
      allocate_environment();
      GONext();
    }
#else
    PREG = PREG->u.Otapl.d;
    PREFETCH_OP(PREG);
    GONext();
#endif /* TABLING_CALL_SUBSUMPTION */
  ENDPBOp();

  PBOp(table_try_single, Otapl)
    tab_ent_ptr tab_ent;
    sg_fr_ptr sg_fr;
    
    dprintf("===> TABLE_TRY_SINGLE\n");

    check_trail(TR);
    tab_ent = PREG->u.Otapl.te;
    YENV2MEM;
    sg_fr = subgoal_search(PREG, YENV_ADDRESS);
    MEM2YENV;
    
    LOCK(SgFr_lock(sg_fr));
    
    if (is_new_generator_call(sg_fr)) {
      /* subgoal new */
      init_subgoal_frame(sg_fr);
      
      UNLOCK(SgFr_lock(sg_fr));
#ifdef DETERMINISTIC_TABLING
      if (IsMode_Batched(TabEnt_mode(tab_ent))) {
	      store_deterministic_generator_node(tab_ent, sg_fr);
      } else
#endif /* DETERMINISTIC_TABLING */
      {
	      store_generator_node(tab_ent, sg_fr, PREG->u.Otapl.s, COMPLETION);
      }
#ifdef TABLING_CALL_SUBSUMPTION
      check_ground_generator(sg_fr, tab_ent);
#endif
      PREG = PREG->u.Otapl.d;  /* should work also with PREG = NEXTOP(PREG,Otapl); */
      PREFETCH_OP(PREG);
      allocate_environment();
      GONext();
#ifdef INCOMPLETE_TABLING
    } else if (SgFr_state(sg_fr) == incomplete) {
      /* subgoal incomplete --> start by loading the answers already found */
      
      continuation_ptr cont = SgFr_first_answer(sg_fr);
      ans_node_ptr ans_node = continuation_answer(cont);
      
      CELL *subs_ptr = YENV;
      init_subgoal_frame(sg_fr);
      UNLOCK(SgFr_lock(sg_fr));
      
      SgFr_try_answer(sg_fr) = cont;
      
      store_generator_node(tab_ent, sg_fr, PREG->u.Otapl.s, TRY_ANSWER);
      PREG = (yamop *) CPREG;
      PREFETCH_OP(PREG);
      CONSUME_VARIANT_ANSWER(ans_node, subs_ptr);
      YENV = ENV;
      GONext();
#endif /* INCOMPLETE_TABLING */
    } else if (is_new_consumer_call(sg_fr)) {
      dprintf("TABLE_TRY_SINGLE NEW_CONSUMER\n");
      /* new consumer */
      choiceptr leader_cp;
      int leader_dep_on_stack;
      
      find_dependency_node(sg_fr, leader_cp, leader_dep_on_stack);
      UNLOCK(SgFr_lock(sg_fr));
      find_leader_node(leader_cp, leader_dep_on_stack);
      store_consumer_node(tab_ent, sg_fr, leader_cp, leader_dep_on_stack);
      
      init_consumer_subgoal_frame(sg_fr);

#ifdef OPTYAP_ERRORS
      if (PARALLEL_EXECUTION_MODE) {
	      choiceptr aux_cp;
	      aux_cp = B;
	      while (YOUNGER_CP(aux_cp, Get_LOCAL_top_cp_on_stack()))
	        aux_cp = aux_cp->cp_b;
	      if (aux_cp->cp_or_fr != DepFr_top_or_fr(LOCAL_top_dep_fr))
	        OPTYAP_ERROR_MESSAGE("Error on DepFr_top_or_fr (table_try)");
	      aux_cp = B;
	      while (YOUNGER_CP(aux_cp, DepFr_leader_cp(LOCAL_top_dep_fr)))
	        aux_cp = aux_cp->cp_b;
	      if (aux_cp != DepFr_leader_cp(LOCAL_top_dep_fr))
	        OPTYAP_ERROR_MESSAGE("Error on DepFr_leader_cp (table_try)");
      }
#endif /* OPTYAP_ERRORS */
      goto answer_resolution;
    } else {
      /* subgoal completed */
      dprintf("TABLE_TRY_SINGLE COMPLETE SUBGOAL\n");

      switch(SgFr_type(sg_fr)) {
        case VARIANT_PRODUCER_SFT:
        case SUBSUMPTIVE_PRODUCER_SFT:
          check_no_answers(sg_fr);
          check_yes_answer(sg_fr);

          limit_tabling_remove_sf(sg_fr);

          if (TabEnt_is_load(tab_ent)) {
            load_variant_answers_from_sf(sg_fr, tab_ent, YENV);
    	    } else {
            ensure_subgoal_is_compiled(sg_fr);
            exec_subgoal_compiled_trie(sg_fr);
    	    }
          break;
#ifdef TABLING_CALL_SUBSUMPTION
        case SUBSUMED_CONSUMER_SFT:
          if(TabEnt_is_load(tab_ent)) {
            compute_subsumptive_consumer_answer_list(sg_fr);
            check_no_answers(sg_fr);
            load_subsumptive_answers_from_sf(sg_fr, tab_ent, YENV);
    	    } else {
            set_subsumptive_producer(sg_fr);
            check_no_answers(sg_fr);
            ensure_subgoal_is_compiled(sg_fr);
            exec_subgoal_compiled_trie(sg_fr);
    	    }
          break;
        case GROUND_PRODUCER_SFT:
          if(TabEnt_is_load(tab_ent)) {
            check_no_answers(sg_fr);
            load_subsumptive_answers_from_sf(sg_fr, tab_ent, YENV);
          } else {
            exec_ground_trie(tab_ent);
          }
          break;
        case GROUND_CONSUMER_SFT:
          if(TabEnt_is_load(tab_ent)) {
            compute_ground_consumer_answer_list(sg_fr);
            check_no_answers(sg_fr);
            load_subsumptive_answers_from_sf(sg_fr, tab_ent, YENV);
          } else {
            exec_ground_trie(tab_ent);
          }
          break;
#endif /* TABLING_CALL_SUBSUMPTION */
          default: break;
      }
    }
    ENDPBOp();

  PBOp(table_try_me, Otapl)
    tab_ent_ptr tab_ent;
    sg_fr_ptr sg_fr;
    
    dprintf("===> TABLE_TRY_ME\n");

    check_trail(TR);
    tab_ent = PREG->u.Otapl.te;
    YENV2MEM;
    sg_fr = subgoal_search(PREG, YENV_ADDRESS);
    MEM2YENV;
    
    LOCK(SgFr_lock(sg_fr));
    
    if (is_new_generator_call(sg_fr)) {
      /* subgoal new */
      init_subgoal_frame(sg_fr);

      UNLOCK(SgFr_lock(sg_fr));
      store_generator_node(tab_ent, sg_fr, PREG->u.Otapl.s, PREG->u.Otapl.d);
#ifdef TABLING_CALL_SUBSUMPTION
      check_ground_generator(sg_fr, tab_ent);
#endif
      PREG = NEXTOP(PREG, Otapl);
      PREFETCH_OP(PREG);
      allocate_environment();
      GONext();
#ifdef INCOMPLETE_TABLING
    } else if (SgFr_state(sg_fr) == incomplete) {
      /* subgoal incomplete --> start by loading the answers already found */
      continuation_ptr cont = SgFr_first_answer(sg_fr);
      ans_node_ptr ans_node = continuation_answer(cont);
      
      CELL *subs_ptr = YENV;
      init_subgoal_frame(sg_fr);
      UNLOCK(SgFr_lock(sg_fr));
      
      SgFr_try_answer(sg_fr) = cont;
      
      store_generator_node(tab_ent, sg_fr, PREG->u.Otapl.s, TRY_ANSWER);
      PREG = (yamop *) CPREG;
      PREFETCH_OP(PREG);
      CONSUME_VARIANT_ANSWER(ans_node, subs_ptr);
      YENV = ENV;
      GONext();
#endif /* INCOMPLETE_TABLING */
    } else if (is_new_consumer_call(sg_fr)) {
      dprintf("TABLE_TRY_ME NEW_CONSUMER\n");
      /* new consumer */
      choiceptr leader_cp;
      int leader_dep_on_stack;
      
      find_dependency_node(sg_fr, leader_cp, leader_dep_on_stack);
      UNLOCK(SgFr_lock(sg_fr));
      find_leader_node(leader_cp, leader_dep_on_stack);
      store_consumer_node(tab_ent, sg_fr, leader_cp, leader_dep_on_stack);

      init_consumer_subgoal_frame(sg_fr);
        
#ifdef OPTYAP_ERRORS
      if (PARALLEL_EXECUTION_MODE) {
	      choiceptr aux_cp;
	      aux_cp = B;
	      while (YOUNGER_CP(aux_cp, Get_LOCAL_top_cp_on_stack()))
	        aux_cp = aux_cp->cp_b;
	      if (aux_cp->cp_or_fr != DepFr_top_or_fr(LOCAL_top_dep_fr))
	        OPTYAP_ERROR_MESSAGE("Error on DepFr_top_or_fr (table_try)");
	      aux_cp = B;
	      while (YOUNGER_CP(aux_cp, DepFr_leader_cp(LOCAL_top_dep_fr)))
	        aux_cp = aux_cp->cp_b;
	      if (aux_cp != DepFr_leader_cp(LOCAL_top_dep_fr))
	        OPTYAP_ERROR_MESSAGE("Error on DepFr_leader_cp (table_try)");
      }
#endif /* OPTYAP_ERRORS */
      goto answer_resolution;
    } else {
      /* subgoal completed */
      dprintf("TABLE_TRY_ME COMPLETE SUBGOAL\n");

      switch(SgFr_type(sg_fr)) {
        case VARIANT_PRODUCER_SFT:
        case SUBSUMPTIVE_PRODUCER_SFT:
          check_no_answers(sg_fr);
          check_yes_answer(sg_fr);

          limit_tabling_remove_sf(sg_fr);

          if (TabEnt_is_load(tab_ent)) {
            load_variant_answers_from_sf(sg_fr, tab_ent, YENV);
    	    } else {
            ensure_subgoal_is_compiled(sg_fr);
            exec_subgoal_compiled_trie(sg_fr);
    	    }
          break;
#ifdef TABLING_CALL_SUBSUMPTION
        case SUBSUMED_CONSUMER_SFT:
          if(TabEnt_is_load(tab_ent)) {
            compute_subsumptive_consumer_answer_list(sg_fr);
            check_no_answers(sg_fr);
            load_subsumptive_answers_from_sf(sg_fr, tab_ent, YENV);
    	    } else {
            set_subsumptive_producer(sg_fr);
            check_no_answers(sg_fr);
            ensure_subgoal_is_compiled(sg_fr);
            exec_subgoal_compiled_trie(sg_fr);
    	    }
          break;
        case GROUND_PRODUCER_SFT:
          if(TabEnt_is_load(tab_ent)) {
            check_no_answers(sg_fr);
            load_subsumptive_answers_from_sf(sg_fr, tab_ent, YENV);
          } else {
            exec_ground_trie(tab_ent);
          }
          break;
        case GROUND_CONSUMER_SFT:
          if(TabEnt_is_load(tab_ent)) {
            compute_ground_consumer_answer_list(sg_fr);
            check_no_answers(sg_fr);
            load_subsumptive_answers_from_sf(sg_fr, tab_ent, YENV);
          } else {
            exec_ground_trie(tab_ent);
          }
          break;
#endif /* TABLING_CALL_SUBSUMPTION */
          default: break;
      }
    }
  ENDPBOp();



  PBOp(table_try, Otapl)
    tab_ent_ptr tab_ent;
    sg_fr_ptr sg_fr;
    
    dprintf("===> TABLE_TRY\n");

    check_trail(TR);
    tab_ent = PREG->u.Otapl.te;
    YENV2MEM;
    sg_fr = subgoal_search(PREG, YENV_ADDRESS);
    MEM2YENV;
    
    LOCK(SgFr_lock(sg_fr));
    
    if (is_new_generator_call(sg_fr)) {
      /* subgoal new */
      init_subgoal_frame(sg_fr);
      UNLOCK(SgFr_lock(sg_fr));
      store_generator_node(tab_ent, sg_fr, PREG->u.Otapl.s, NEXTOP(PREG,Otapl));
#ifdef TABLING_CALL_SUBSUMPTION
      check_ground_generator(sg_fr, tab_ent);
#endif
      PREG = PREG->u.Otapl.d;
      PREFETCH_OP(PREG);
      allocate_environment();
      GONext();
#ifdef INCOMPLETE_TABLING
    } else if (SgFr_state(sg_fr) == incomplete) {
      /* subgoal incomplete --> start by loading the answers already found */
      continuation_ptr cont = SgFr_first_answer(sg_fr);
      ans_node_ptr ans_node = continuation_answer(cont);

      CELL *subs_ptr = YENV;
      init_subgoal_frame(sg_fr);
      UNLOCK(SgFr_lock(sg_fr));

      SgFr_try_answer(sg_fr) = cont;
      store_generator_node(tab_ent, sg_fr, PREG->u.Otapl.s, TRY_ANSWER);
      PREG = (yamop *) CPREG;
      PREFETCH_OP(PREG);
      CONSUME_VARIANT_ANSWER(ans_node, subs_ptr);
      YENV = ENV;
      GONext();
#endif /* INCOMPLETE_TABLING */
    } else if (is_new_consumer_call(sg_fr)) {
      dprintf("TABLE_TRY NEW_CONSUMER\n");
      /* new consumer */
      choiceptr leader_cp;
      int leader_dep_on_stack;
      
      find_dependency_node(sg_fr, leader_cp, leader_dep_on_stack);
      UNLOCK(SgFr_lock(sg_fr));
      find_leader_node(leader_cp, leader_dep_on_stack);
      store_consumer_node(tab_ent, sg_fr, leader_cp, leader_dep_on_stack);
      
      init_consumer_subgoal_frame(sg_fr);
      
#ifdef OPTYAP_ERRORS
      if (PARALLEL_EXECUTION_MODE) {
	      choiceptr aux_cp;
	      aux_cp = B;
	      while (YOUNGER_CP(aux_cp, Get_LOCAL_top_cp_on_stack()))
	        aux_cp = aux_cp->cp_b;
	      if (aux_cp->cp_or_fr != DepFr_top_or_fr(LOCAL_top_dep_fr))
	        OPTYAP_ERROR_MESSAGE("Error on DepFr_top_or_fr (table_try)");
	      aux_cp = B;
	      while (YOUNGER_CP(aux_cp, DepFr_leader_cp(LOCAL_top_dep_fr)))
	        aux_cp = aux_cp->cp_b;
	      if (aux_cp != DepFr_leader_cp(LOCAL_top_dep_fr))
	        OPTYAP_ERROR_MESSAGE("Error on DepFr_leader_cp (table_try)");
      }
#endif /* OPTYAP_ERRORS */
      goto answer_resolution;
    } else {
      /* subgoal completed */
      dprintf("TABLE_TRY COMPLETE SUBGOAL\n");
      
      switch(SgFr_type(sg_fr)) {
        case VARIANT_PRODUCER_SFT:
        case SUBSUMPTIVE_PRODUCER_SFT:
          check_no_answers(sg_fr);
          check_yes_answer(sg_fr);

          limit_tabling_remove_sf(sg_fr);

          if (TabEnt_is_load(tab_ent)) {
            load_variant_answers_from_sf(sg_fr, tab_ent, YENV);
    	    } else {
            ensure_subgoal_is_compiled(sg_fr);
            exec_subgoal_compiled_trie(sg_fr);
    	    }
          break;
#ifdef TABLING_CALL_SUBSUMPTION
        case SUBSUMED_CONSUMER_SFT:
          if(TabEnt_is_load(tab_ent)) {
            compute_subsumptive_consumer_answer_list(sg_fr);
            check_no_answers(sg_fr);
            load_subsumptive_answers_from_sf(sg_fr, tab_ent, YENV);
    	    } else {
            set_subsumptive_producer(sg_fr);
            check_no_answers(sg_fr);
            ensure_subgoal_is_compiled(sg_fr);
            exec_subgoal_compiled_trie(sg_fr);
    	    }
          break;
        case GROUND_PRODUCER_SFT:
          if(TabEnt_is_load(tab_ent)) {
            check_no_answers(sg_fr);
            load_subsumptive_answers_from_sf(sg_fr, tab_ent, YENV);
          } else {
            exec_ground_trie(tab_ent);
          }
          break;
        case GROUND_CONSUMER_SFT:
          if(TabEnt_is_load(tab_ent)) {
            compute_ground_consumer_answer_list(sg_fr);
            check_no_answers(sg_fr);
            load_subsumptive_answers_from_sf(sg_fr, tab_ent, YENV);
          } else {
            exec_ground_trie(tab_ent);
          }
          break;
#endif /* TABLING_CALL_SUBSUMPTION */
          default: break;
      }
    }
  ENDPBOp();


  Op(table_retry_me, Otapl)
    dprintf("===> TABLE_RETRY_ME\n");
    
#ifdef TABLING_CALL_SUBSUMPTION
    sg_fr_ptr sg_fr = GEN_CP(B)->cp_sg_fr;
     
    if(SgFr_is_ground_producer(sg_fr)) {
      dprintf("NEW_ANSWER_CP=NULL\n");
      SgFr_new_answer_cp((grounded_sf_ptr)sg_fr) = NULL;
    }
#endif /* TABLING_CALL_SUBSUMPTION */
    
    restore_generator_node(PREG->u.Otapl.s, PREG->u.Otapl.d);
    YENV = (CELL *) PROTECT_FROZEN_B(B);
    set_cut(YENV, B->cp_b);
    SET_BB(NORM_CP(YENV));
    allocate_environment();
    PREG = NEXTOP(PREG,Otapl);
    GONext();
  ENDOp();



  Op(table_retry, Otapl)
    dprintf("===> TABLE_RETRY\n");
    
#ifdef TABLING_CALL_SUBSUMPTION
    sg_fr_ptr sg_fr = GEN_CP(B)->cp_sg_fr;
     
    if(SgFr_is_ground_producer(sg_fr)) {
      dprintf("NEW_ANSWER_CP=NULL\n");
      SgFr_new_answer_cp((grounded_sf_ptr)sg_fr) = NULL;
    }
#endif /* TABLING_CALL_SUBSUMPTION */
    
    restore_generator_node(PREG->u.Otapl.s, NEXTOP(PREG,Otapl));
    YENV = (CELL *) PROTECT_FROZEN_B(B);
    set_cut(YENV, B->cp_b);
    SET_BB(NORM_CP(YENV));
    allocate_environment();
    PREG = PREG->u.Otapl.d;
    GONext();
  ENDOp();



  Op(table_trust_me, Otapl)
    dprintf("===> TABLE_TRUST_ME\n");
    
#ifdef TABLING_CALL_SUBSUMPTION
    sg_fr_ptr sg_fr = GEN_CP(B)->cp_sg_fr;

    if(SgFr_is_ground_producer(sg_fr)) {
      dprintf("NEW_ANSWER_CP=NULL\n");
      SgFr_new_answer_cp((grounded_sf_ptr)sg_fr) = NULL;
    }
#endif /* TABLING_CALL_SUBSUMPTION */

    restore_generator_node(PREG->u.Otapl.s, COMPLETION);
#ifdef DETERMINISTIC_TABLING
    if (B_FZ > B && IS_BATCHED_NORM_GEN_CP(B)) {   
      CELL *subs_ptr = (CELL *)(GEN_CP(B) + 1) + PREG->u.Otapl.s;
      choiceptr gcp = NORM_CP(DET_GEN_CP(subs_ptr) - 1);
      sg_fr_ptr sg_fr = GEN_CP(B)->cp_sg_fr; 
      DET_GEN_CP(gcp)->cp_sg_fr = sg_fr;         
      gcp->cp_h     = B->cp_h;
#ifdef DEPTH_LIMIT
      gcp->cp_depth = B->cp_depth;
#endif /* DEPTH_LIMIT */
      gcp->cp_tr    = B->cp_tr;
      gcp->cp_b     = B->cp_b;
      gcp->cp_ap    = B->cp_ap;
      SgFr_choice_point(sg_fr) = B = gcp;       
    }
#endif /* DETERMINISTIC_TABLING */
    YENV = (CELL *) PROTECT_FROZEN_B(B);
    set_cut(YENV, B->cp_b);
    SET_BB(NORM_CP(YENV));
    allocate_environment();
    PREG = NEXTOP(PREG,Otapl);
    GONext();
  ENDOp();



  Op(table_trust, Otapl)
#ifdef TABLING_CALL_SUBSUMPTION
    sg_fr_ptr sg_fr = GEN_CP(B)->cp_sg_fr;
     
    if(SgFr_is_ground_producer(sg_fr)) {
      dprintf("NEW_ANSWER_CP=NULL\n");
      SgFr_new_answer_cp((grounded_sf_ptr)sg_fr) = NULL;
    }
#endif /* TABLING_CALL_SUBSUMPTION */

    restore_generator_node(PREG->u.Otapl.s, COMPLETION);
    
    dprintf("===> TABLE_TRUST ");

#ifdef DETERMINISTIC_TABLING
  if (B_FZ > B && IS_BATCHED_NORM_GEN_CP(B)) {    
      CELL *subs_ptr = (CELL *)(GEN_CP(B) + 1) + PREG->u.Otapl.s;
      choiceptr gcp = NORM_CP(DET_GEN_CP(subs_ptr) - 1);
      sg_fr_ptr sg_fr = GEN_CP(B)->cp_sg_fr; 
      DET_GEN_CP(gcp)->cp_sg_fr = sg_fr;         
      gcp->cp_h     = B->cp_h;
#ifdef DEPTH_LIMIT
      gcp->cp_depth = B->cp_depth;
#endif /* DEPTH_LIMIT */
      gcp->cp_tr    = B->cp_tr;
      gcp->cp_b     = B->cp_b;
      gcp->cp_ap    = B->cp_ap;
      SgFr_choice_point(sg_fr) = B = gcp;
    }
#endif /* DETERMINISTIC_TABLING */
    YENV = (CELL *) PROTECT_FROZEN_B(B);
    set_cut(YENV, B->cp_b);
    SET_BB(NORM_CP(YENV));
    allocate_environment();
    PREG = PREG->u.Otapl.d;
    GONext();
  ENDOp();



  PBOp(table_new_answer, s)
    CELL *subs_ptr;
    choiceptr gcp;
    sg_fr_ptr sg_fr;
    ans_node_ptr ans_node;

    dprintf("===> TABLE_NEW_ANSWER\n");

    gcp = NORM_CP(YENV[E_B]);
#ifdef DETERMINISTIC_TABLING
    if (IS_DET_GEN_CP(gcp)){  
      sg_fr = DET_GEN_CP(gcp)->cp_sg_fr;
      subs_ptr = (CELL *)(DET_GEN_CP(gcp) + 1) ; 
    } else
#endif /* DETERMINISTIC_TABLING */
    {
      sg_fr = GEN_CP(gcp)->cp_sg_fr;
      subs_ptr = (CELL *)(GEN_CP(gcp) + 1) + PREG->u.s.s;
    }
#if defined(TABLING_ERRORS) && !defined(DETERMINISTIC_TABLING)
    {
      int i, j, arity_args, arity_subs;
      CELL *aux_args;
      CELL *aux_subs;

      arity_args = PREG->u.s.s;
      arity_subs = *subs_ptr;
      aux_args = (CELL *)(GEN_CP(gcp) + 1);
      aux_subs = subs_ptr;
      for (i = 1; i <= arity_subs; i++) {
        Term term_subs = Deref(*(aux_subs + i));
        for (j = 0; j < arity_args; j++) {
          Term term_arg = Deref(*(aux_args + j));
          if (term_subs == term_arg) break;
	}
        if (j == arity_args)
          TABLING_ERROR_MESSAGE("j == arity_args (table_new_answer)");
      }
    }
#endif /* TABLING_ERRORS && !DETERMINISTIC_TABLING */
#ifdef TABLE_LOCK_AT_ENTRY_LEVEL
    LOCK(SgFr_lock(sg_fr));
#endif /* TABLE_LOCK_LEVEL */
    ans_node = answer_search(sg_fr, subs_ptr);
#if defined(TABLE_LOCK_AT_NODE_LEVEL)
    LOCK(TrNode_lock(ans_node));
#elif defined(TABLE_LOCK_AT_WRITE_LEVEL)
    LOCK_TABLE(ans_node);
#endif /* TABLE_LOCK_LEVEL */
    if (! IS_ANSWER_LEAF_NODE(ans_node)) {
      /* new answer */
#ifdef TABLING_INNER_CUTS
      /* check for potencial prunings */
      if (! BITMAP_empty(GLOBAL_bm_pruning_workers)) {
        int until_depth, depth;

        until_depth = OrFr_depth(SgFr_gen_top_or_fr(sg_fr));
        depth = OrFr_depth(LOCAL_top_or_fr);
        if (depth > until_depth) {
          int i, ltt;
          bitmap prune_members, members;
          or_fr_ptr leftmost_or_fr, or_fr, nearest_or_fr;

          BITMAP_copy(prune_members, GLOBAL_bm_pruning_workers);
          BITMAP_delete(prune_members, worker_id);
          ltt = BRANCH_LTT(worker_id, depth);
          BITMAP_intersection(members, prune_members, OrFr_members(LOCAL_top_or_fr));
          if (members) {
            for (i = 0; i < number_workers; i++) {
              if (BITMAP_member(members, i) && 
                  BRANCH_LTT(i, depth) > ltt && 
                  EQUAL_OR_YOUNGER_CP(Get_LOCAL_top_cp(), REMOTE_pruning_scope(i))) {
                leftmost_or_fr = LOCAL_top_or_fr;
  pending_table_new_answer:
#if defined(TABLE_LOCK_AT_ENTRY_LEVEL)
                UNLOCK(SgFr_lock(sg_fr));
#elif defined(TABLE_LOCK_AT_NODE_LEVEL)
                UNLOCK(TrNode_lock(ans_node));
#elif defined(TABLE_LOCK_AT_WRITE_LEVEL)
                UNLOCK_TABLE(ans_node);
#endif /* TABLE_LOCK_LEVEL */
                LOCK_OR_FRAME(leftmost_or_fr);
                if (Get_LOCAL_prune_request()) {
                  UNLOCK_OR_FRAME(leftmost_or_fr);
                  SCHEDULER_GET_WORK();
                } else {
                  CUT_store_tg_answer(leftmost_or_fr, ans_node, gcp, ltt);
                  UNLOCK_OR_FRAME(leftmost_or_fr);
                }
		if (IS_BATCHED_GEN_CP(gcp)) {
                  /* deallocate and procceed */
                  PREG = (yamop *) YENV[E_CP];
                  PREFETCH_OP(PREG);
                  CPREG = PREG;
                  SREG = YENV;
                  ENV = YENV = (CELL *) YENV[E_E];
#ifdef DEPTH_LIMIT
		  DEPTH = YENV[E_DEPTH];
#endif /* DEPTH_LIMIT */
                  GONext();
		} else {
                  /* fail */
                  goto fail;
		}
              }
	    }
            BITMAP_minus(prune_members, members);
	  }
          leftmost_or_fr = OrFr_nearest_leftnode(LOCAL_top_or_fr);
          depth = OrFr_depth(leftmost_or_fr);
          if (depth > until_depth) {
            ltt = BRANCH_LTT(worker_id, depth);
            BITMAP_intersection(members, prune_members, OrFr_members(leftmost_or_fr));
            if (members) {
              for (i = 0; i < number_workers; i++) {
                if (BITMAP_member(members, i) &&
                    BRANCH_LTT(i, depth) > ltt &&
                    EQUAL_OR_YOUNGER_CP(GetOrFr_node(leftmost_or_fr), REMOTE_pruning_scope(i)))
                  goto pending_table_new_answer;
	      }
              BITMAP_minus(prune_members, members);
            }
            /* reaching that point we should update the nearest leftnode data */
            leftmost_or_fr = OrFr_nearest_leftnode(leftmost_or_fr);
            depth = OrFr_depth(leftmost_or_fr);
            while (depth > until_depth) {
              ltt = BRANCH_LTT(worker_id, depth);
              BITMAP_intersection(members, prune_members, OrFr_members(leftmost_or_fr));
              if (members) {
                for (i = 0; i < number_workers; i++) {
                  if (BITMAP_member(members, i) &&
                      BRANCH_LTT(i, depth) > ltt &&
                      EQUAL_OR_YOUNGER_CP(GetOrFr_node(leftmost_or_fr), REMOTE_pruning_scope(i))) {
                    /* update nearest leftnode data */
                    or_fr = LOCAL_top_or_fr;
                    nearest_or_fr = OrFr_nearest_leftnode(or_fr);
                    while (OrFr_depth(nearest_or_fr) > depth) {
                      LOCK_OR_FRAME(or_fr);
                      OrFr_nearest_leftnode(or_fr) = leftmost_or_fr;
                      UNLOCK_OR_FRAME(or_fr);
                      or_fr = nearest_or_fr;
                      nearest_or_fr = OrFr_nearest_leftnode(or_fr);
                    }
                    goto pending_table_new_answer;
  	       	  }
		}
		BITMAP_minus(prune_members, members);
              }
              leftmost_or_fr = OrFr_nearest_leftnode(leftmost_or_fr);
              depth = OrFr_depth(leftmost_or_fr);
            }
            /* update nearest leftnode data */
            or_fr = LOCAL_top_or_fr;
            nearest_or_fr = OrFr_nearest_leftnode(or_fr);
            while (OrFr_depth(nearest_or_fr) > depth) {
              LOCK_OR_FRAME(or_fr);
              OrFr_nearest_leftnode(or_fr) = leftmost_or_fr;
              UNLOCK_OR_FRAME(or_fr);
              or_fr = nearest_or_fr;
              nearest_or_fr = OrFr_nearest_leftnode(or_fr);
            }
          }
        }
      }

      /* check for prune requests */
      if (Get_LOCAL_prune_request()) {
#if defined(TABLE_LOCK_AT_ENTRY_LEVEL)
        UNLOCK(SgFr_lock(sg_fr));
#elif defined(TABLE_LOCK_AT_NODE_LEVEL)
        UNLOCK(TrNode_lock(ans_node));
#elif defined(TABLE_LOCK_AT_WRITE_LEVEL)
        UNLOCK_TABLE(ans_node);
#endif /* TABLE_LOCK_LEVEL */
        SCHEDULER_GET_WORK();
      }
#endif /* TABLING_INNER_CUTS */

      TAG_AS_ANSWER_LEAF_NODE(ans_node);

#if defined(TABLE_LOCK_AT_NODE_LEVEL)
      UNLOCK(TrNode_lock(ans_node));
      LOCK(SgFr_lock(sg_fr));
#elif defined(TABLE_LOCK_AT_WRITE_LEVEL)
      UNLOCK_TABLE(ans_node);
      LOCK(SgFr_lock(sg_fr));
#endif /* TABLE_LOCK_LEVEL */

      push_new_answer_set(ans_node, SgFr_first_answer(sg_fr), SgFr_last_answer(sg_fr));
      
#ifdef TABLING_CALL_SUBSUMPTION
      if(SgFr_is_ground_producer(sg_fr)) {
        dprintf("NEW_ANSWER_CP=%d\n", (int)B);
        SgFr_new_answer_cp((grounded_sf_ptr)sg_fr) = B;
      }
#endif

#ifdef TABLING_ERRORS
      if(SgFr_first_answer(sg_fr)) {
        // found answers
        continuation_ptr aux = SgFr_first_answer(sg_fr);
          
        do {
          if(!IS_ANSWER_LEAF_NODE(continuation_answer(aux)))
            TABLING_ERROR_MESSAGE("! IS_ANSWER_LEAF_NODE(continuation_answer(aux)) (table_new_answer)");
        } while((aux = continuation_next(aux)));
      }
#endif /* TABLING_ERRORS */
      UNLOCK(SgFr_lock(sg_fr));
      if (IS_BATCHED_GEN_CP(gcp)) {
#ifdef TABLING_EARLY_COMPLETION
	if (gcp == PROTECT_FROZEN_B(B) && (*subs_ptr == 0 || gcp->cp_ap == COMPLETION)) {
	  /* if the current generator choice point is the topmost choice point and the current */
	  /* call is deterministic (i.e., the number of substitution variables is zero or      */
	  /* there are no more alternatives) then the current answer is deterministic and we   */
	  /* can perform an early completion and remove the current generator choice point     */
	  private_completion(sg_fr);
	  B = B->cp_b;
	  SET_BB(PROTECT_FROZEN_B(B));
	} else if (*subs_ptr == 0) {
	  /* if the number of substitution variables is zero, an answer is sufficient to perform */
          /* an early completion, but the current generator choice point cannot be removed       */
	  mark_as_completed(sg_fr);
	  if (gcp->cp_ap != NULL)
	    gcp->cp_ap = COMPLETION;
	}
#endif /* TABLING_EARLY_COMPLETION */
        /* deallocate and procceed */
        PREG = (yamop *) YENV[E_CP];
        PREFETCH_OP(PREG);
        CPREG = PREG;
        SREG = YENV;
        ENV = YENV = (CELL *) YENV[E_E];
#ifdef DEPTH_LIMIT
	DEPTH = YENV[E_DEPTH];
#endif /* DEPTH_LIMIT */
        GONext();
      } else {
#ifdef TABLING_EARLY_COMPLETION
	if (*subs_ptr == 0) {
	  /* if the number of substitution variables is zero, an answer is sufficient to perform */
          /* an early completion, but the current generator choice point cannot be removed       */
	  mark_as_completed(sg_fr);
	  if (gcp->cp_ap != ANSWER_RESOLUTION)
	    gcp->cp_ap = COMPLETION;
	}
#endif /* TABLING_EARLY_COMPLETION */
        /* fail */
        goto fail;
      }
    } else {
      /* repeated answer */
#if defined(TABLE_LOCK_AT_ENTRY_LEVEL)
      UNLOCK(SgFr_lock(sg_fr));
#elif defined(TABLE_LOCK_AT_NODE_LEVEL)
      UNLOCK(TrNode_lock(ans_node));
#elif defined(TABLE_LOCK_AT_WRITE_LEVEL)
      UNLOCK_TABLE(ans_node);
#endif /* TABLE_LOCK_LEVEL */
      goto fail;
    }
  ENDPBOp();



  BOp(table_answer_resolution, Otapl)
    
#ifdef YAPOR
    if (SCH_top_shared_cp(B)) {
      UNLOCK_OR_FRAME(LOCAL_top_or_fr);
    }
#endif /* YAPOR */
    
  answer_resolution:
  
    INIT_PREFETCH()
    dep_fr_ptr dep_fr;
    

#ifdef OPTYAP_ERRORS
    if (SCH_top_shared_cp(B)) {
      if (B->cp_or_fr->alternative != ANSWER_RESOLUTION)
        OPTYAP_ERROR_MESSAGE("B->cp_or_fr->alternative != ANSWER_RESOLUTION (answer_resolution)");
    } else {
      if (B->cp_ap != ANSWER_RESOLUTION)
        OPTYAP_ERROR_MESSAGE("B->cp_ap != ANSWER_RESOLUTION (answer_resolution)");
    }
#endif /* OPTYAP_ERRORS */
    dep_fr = CONS_CP(B)->cp_dep_fr;
#ifdef FDEBUG
    dprintf("===> TABLE_ANSWER_RESOLUTION ");
    printSubgoalTriePath(stdout, SgFr_leaf(DepFr_sg_fr(dep_fr)), SgFr_tab_ent(DepFr_sg_fr(dep_fr)));
    dprintf("\n");
#endif
    LOCK(DepFr_lock(dep_fr));
    
    ans_node_ptr ans_node;
    continuation_ptr next = get_next_answer_continuation(dep_fr);
    
    if(next) {
      /* unconsumed answer */
      ans_node = continuation_answer(next);
      DepFr_last_answer(dep_fr) = next;
      UNLOCK(DepFr_lock(dep_fr));
      consume_answer_and_procceed(dep_fr, ans_node);
    }

    UNLOCK(DepFr_lock(dep_fr));

#ifdef YAPOR
    if (B == DepFr_leader_cp(LOCAL_top_dep_fr)) {
      /*  B is a generator-consumer node  **
      ** never here if batched scheduling */
#ifdef TABLING_ERRORS
      if (IS_BATCHED_GEN_CP(B))
        TABLING_ERROR_MESSAGE("IS_BATCHED_GEN_CP(B) (answer_resolution)");
#endif /* TABLING_ERRORS */
      goto completion;
    }
#endif /* YAPOR */

    /* no unconsumed answers */
    if (DepFr_backchain_cp(dep_fr) == NULL) {
      /* normal backtrack */
#ifdef YAPOR
      if (SCH_top_shared_cp(B)) {
        SCHEDULER_GET_WORK();
      }
#endif /* YAPOR */
      B = B->cp_b;
      goto fail;
    } else {
      /* chain backtrack */
      choiceptr top_chain_cp, chain_cp;
#ifdef YAPOR
      or_fr_ptr start_or_fr, end_or_fr;
#endif /* YAPOR */

      /* find chain choice point to backtrack */
      top_chain_cp = DepFr_backchain_cp(dep_fr);
      chain_cp = DepFr_leader_cp(LOCAL_top_dep_fr);
      if (YOUNGER_CP(top_chain_cp, chain_cp))
        chain_cp = top_chain_cp;
      
#ifdef TABLING_ERRORS
      if (EQUAL_OR_YOUNGER_CP(top_chain_cp, B))
        TABLING_ERROR_MESSAGE("EQUAL_OR_YOUNGER_CP(top_chain_cp, B) (answer_resolution)");
      else if (EQUAL_OR_YOUNGER_CP(chain_cp, B))
        TABLING_ERROR_MESSAGE("EQUAL_OR_YOUNGER_CP(chain_cp, B) (answer_resolution)");
#endif /* TABLING_ERRORS */

      /* check for dependency frames with unconsumed answers */
      dep_fr = DepFr_next(dep_fr);
      while (YOUNGER_CP(DepFr_cons_cp(dep_fr), chain_cp)) {
        LOCK(DepFr_lock(dep_fr));
        
#ifdef FDEBUG
        printSubgoalTriePath(stdout, SgFr_leaf(DepFr_sg_fr(dep_fr)), SgFr_tab_ent(DepFr_sg_fr(dep_fr)));
        dprintf("\n");
#endif

        ans_node = NULL;
        next = get_next_answer_continuation(dep_fr);
        
        if(next) {
          dprintf("UNCONSUMED ANSWERS\n");
          /* dependency frame with unconsumed answers */
          ans_node = continuation_answer(next);
          DepFr_last_answer(dep_fr) = next;
        } else
          dprintf("no unconsumed answers!\n");

        if(ans_node != NULL) {
#ifdef YAPOR
          if (YOUNGER_CP(DepFr_backchain_cp(dep_fr), top_chain_cp))
#endif /* YAPOR */
            DepFr_backchain_cp(dep_fr) = top_chain_cp;
          UNLOCK(DepFr_lock(dep_fr));

          chain_cp = DepFr_cons_cp(dep_fr);
#ifdef YAPOR
          /* update shared nodes */
          start_or_fr = LOCAL_top_or_fr;
          end_or_fr = DepFr_top_or_fr(dep_fr);
          if (start_or_fr != end_or_fr) {
            LOCAL_top_or_fr = end_or_fr;
            Set_LOCAL_top_cp(GetOrFr_node(end_or_fr));
            do {
              while (YOUNGER_CP(GetOrFr_node(start_or_fr), GetOrFr_node(end_or_fr))) {
                LOCK_OR_FRAME(start_or_fr);
                BITMAP_delete(OrFr_members(start_or_fr), worker_id);
                if (BITMAP_empty(OrFr_members(start_or_fr))) {
                  if (frame_with_suspensions_not_collected(start_or_fr)) {
                    collect_suspension_frames(start_or_fr);
                  }
#ifdef TABLING_INNER_CUTS
                  if (OrFr_tg_solutions(start_or_fr)) {
                    tg_sol_fr_ptr tg_solutions;
                    or_fr_ptr leftmost_until;
                    tg_solutions = OrFr_tg_solutions(start_or_fr);
                    leftmost_until = CUT_leftmost_until(start_or_fr, OrFr_depth(TgSolFr_gen_cp(tg_solutions)->cp_or_fr));
                    OrFr_tg_solutions(start_or_fr) = NULL;
                    UNLOCK_OR_FRAME(start_or_fr);
                    if (leftmost_until) {
                      LOCK_OR_FRAME(leftmost_until);
                      tg_solutions = CUT_store_tg_answers(leftmost_until, tg_solutions,
                                                          BRANCH_LTT(worker_id, OrFr_depth(leftmost_until)));
                      UNLOCK_OR_FRAME(leftmost_until);
                    }
                    CUT_validate_tg_answers(tg_solutions);
                    goto continue_update_loop1;
                  }
#endif /* TABLING_INNER_CUTS */
                }
                UNLOCK_OR_FRAME(start_or_fr);
#ifdef TABLING_INNER_CUTS
  continue_update_loop1:
#endif /* TABLING_INNER_CUTS */
                start_or_fr = OrFr_next(start_or_fr);
  	      }
              while (YOUNGER_CP(GetOrFr_node(end_or_fr), GetOrFr_node(start_or_fr))) {
                LOCK_OR_FRAME(end_or_fr);
                BITMAP_insert(OrFr_members(end_or_fr), worker_id);
                BRANCH(worker_id, OrFr_depth(end_or_fr)) = 1;
                UNLOCK_OR_FRAME(end_or_fr);
                end_or_fr = OrFr_next(end_or_fr);
	      }
    	    } while (start_or_fr != end_or_fr);
            if (Get_LOCAL_prune_request())
              pruning_over_tabling_data_structures(); 	
          }
#endif /* YAPOR */
#ifdef OPTYAP_ERRORS
          if (PARALLEL_EXECUTION_MODE) {
            if (YOUNGER_CP(Get_LOCAL_top_cp(), Get_LOCAL_top_cp_on_stack())) {
              OPTYAP_ERROR_MESSAGE("YOUNGER_CP(Get_LOCAL_top_cp(), LOCAL_top_cp_on_stack) (answer_resolution)");
    	    } else {
              choiceptr aux_cp;
              aux_cp = chain_cp;
              while (aux_cp != Get_LOCAL_top_cp()) {
                if (YOUNGER_CP(Get_LOCAL_top_cp(), aux_cp)) {
                  OPTYAP_ERROR_MESSAGE("LOCAL_top_cp not in branch (answer_resolution)");
                  break;
                }
                if (EQUAL_OR_YOUNGER_CP(Get_LOCAL_top_cp_on_stack(), aux_cp)) {
                  OPTYAP_ERROR_MESSAGE("shared frozen segments in branch (answer_resolution)");
                  break;
                }
                aux_cp = aux_cp->cp_b;
              }
    	    }
	  }
#endif /* OPTYAP_ERRORS */
          /* restore bindings, update registers, consume answer and procceed */
          restore_bindings(B->cp_tr, chain_cp->cp_tr);
#ifdef TABLING_ERRORS
          if (TR != B->cp_tr) {
            if(! IsPairTerm((CELL)TrailTerm(TR - 1)))
              TABLING_ERROR_MESSAGE("! IsPairTerm((CELL)TrailTerm(TR - 1)) (answer_resolution)");
            if ((tr_fr_ptr) RepPair((CELL)TrailTerm(TR - 1)) != B->cp_tr)
              TABLING_ERROR_MESSAGE("RepPair((CELL)TrailTerm(TR - 1)) != B->cp_tr (answer_resolution)");
	  }
#endif /* TABLING_ERRORS */
          B = chain_cp;
          TR = TR_FZ;
          TRAIL_LINK(B->cp_tr);
          consume_answer_and_procceed(dep_fr, ans_node);
	}
        UNLOCK(DepFr_lock(dep_fr));
        dep_fr = DepFr_next(dep_fr);
      }

      /* no dependency frames with unconsumed answers found */
#ifdef YAPOR
      /* update shared nodes */
      if (EQUAL_OR_YOUNGER_CP(Get_LOCAL_top_cp_on_stack(), chain_cp)) {
        end_or_fr = chain_cp->cp_or_fr;
        start_or_fr = LOCAL_top_or_fr;
        if (start_or_fr != end_or_fr) {
          LOCAL_top_or_fr = end_or_fr;
          Set_LOCAL_top_cp(GetOrFr_node(end_or_fr));
          while (start_or_fr != end_or_fr) {
            LOCK_OR_FRAME(start_or_fr);
            BITMAP_delete(OrFr_members(start_or_fr), worker_id);
            if (BITMAP_empty(OrFr_members(start_or_fr))) {
              if (frame_with_suspensions_not_collected(start_or_fr)) {
                collect_suspension_frames(start_or_fr);
              }
#ifdef TABLING_INNER_CUTS
              if (OrFr_tg_solutions(start_or_fr)) {
                tg_sol_fr_ptr tg_solutions;
                or_fr_ptr leftmost_until;
                tg_solutions = OrFr_tg_solutions(start_or_fr);
                leftmost_until = CUT_leftmost_until(start_or_fr, OrFr_depth(TgSolFr_gen_cp(tg_solutions)->cp_or_fr));
                OrFr_tg_solutions(start_or_fr) = NULL;
                UNLOCK_OR_FRAME(start_or_fr);
                if (leftmost_until) {
                  LOCK_OR_FRAME(leftmost_until);
                  tg_solutions = CUT_store_tg_answers(leftmost_until, tg_solutions,
                                                      BRANCH_LTT(worker_id, OrFr_depth(leftmost_until)));
                  UNLOCK_OR_FRAME(leftmost_until);
                }
                CUT_validate_tg_answers(tg_solutions);
                goto continue_update_loop2;
              }
#endif /* TABLING_INNER_CUTS */
            }
            UNLOCK_OR_FRAME(start_or_fr);
#ifdef TABLING_INNER_CUTS
  continue_update_loop2:
#endif /* TABLING_INNER_CUTS */
            start_or_fr = OrFr_next(start_or_fr);
  	  }
          if (Get_LOCAL_prune_request())
            pruning_over_tabling_data_structures(); 
        }
      }
#endif /* YAPOR */
#ifdef OPTYAP_ERRORS
      if (PARALLEL_EXECUTION_MODE) {
        if (YOUNGER_CP(Get_LOCAL_top_cp(), Get_LOCAL_top_cp_on_stack())) {
          OPTYAP_ERROR_MESSAGE("YOUNGER_CP(Get_LOCAL_top_cp(), Get_LOCAL_top_cp_on_stack()) (answer_resolution)");
	} else {
          choiceptr aux_cp;
          aux_cp = chain_cp;
          while (aux_cp != Get_LOCAL_top_cp()) {
            if (YOUNGER_CP(Get_LOCAL_top_cp(), aux_cp)) {
              OPTYAP_ERROR_MESSAGE("LOCAL_top_cp not in branch (answer_resolution)");
              break;
            }
            if (EQUAL_OR_YOUNGER_CP(Get_LOCAL_top_cp_on_stack(), aux_cp)) {
              OPTYAP_ERROR_MESSAGE("shared frozen segments in branch (answer_resolution)");
              break;
            }
            aux_cp = aux_cp->cp_b;
          }
	}
      }
#endif /* OPTYAP_ERRORS */
      /* unbind variables */
      unbind_variables(B->cp_tr, chain_cp->cp_tr);
#ifdef TABLING_ERRORS
      if (TR != B->cp_tr) {
        if(! IsPairTerm((CELL)TrailTerm(TR - 1)))
          TABLING_ERROR_MESSAGE("! IsPairTerm((CELL)TrailTerm(TR - 1)) (answer_resolution)");
        if ((tr_fr_ptr) RepPair((CELL)TrailTerm(TR - 1)) != B->cp_tr)
          TABLING_ERROR_MESSAGE("RepPair((CELL)TrailTerm(TR - 1)) != B->cp_tr (answer_resolution)");
      }
#endif /* TABLING_ERRORS */
      if (DepFr_leader_cp(LOCAL_top_dep_fr) == chain_cp && (
        /* chain_cp is a leader node AND ... */
#ifdef YAPOR
        /* the leader dependency is not on stack OR ... */
        DepFr_leader_dep_is_on_stack(LOCAL_top_dep_fr) == FALSE ||
        /* the leader dependency is on stack (this means that chain_cp is a generator node) and */
#endif /* YAPOR */
        /*                 there are no unexploited alternatives                 **
        ** (NULL if batched scheduling OR ANSWER_RESOLUTION if local scheduling) */
        chain_cp->cp_ap == NULL || chain_cp->cp_ap == ANSWER_RESOLUTION)) {
        B = chain_cp;
        TR = TR_FZ;
        TRAIL_LINK(B->cp_tr);
        goto completion;
      }
      /* backtrack to chain choice point */
      PREG = chain_cp->cp_ap;
      PREFETCH_OP(PREG);
      B = chain_cp;
      TR = TR_FZ;
      TRAIL_LINK(B->cp_tr);
      GONext();
    }
    END_PREFETCH()
  ENDBOp();



  BOp(table_completion, Otapl)
#ifdef FDEBUG
    dprintf("===> TABLE_COMPLETION ");
      sg_fr_ptr sg_fr = GEN_CP(B)->cp_sg_fr;
      printSubgoalTriePath(stdout, SgFr_leaf(sg_fr), SgFr_tab_ent(sg_fr));
      dprintf("\n");
#endif
    
#ifdef YAPOR
    if (SCH_top_shared_cp(B)) {
      if (IS_BATCHED_GEN_CP(B)) {
        SCH_new_alternative(PREG, NULL);
        if (B != DepFr_leader_cp(LOCAL_top_dep_fr) && EQUAL_OR_YOUNGER_CP(B_FZ, B)) {
          /* not leader on that node */
          SCHEDULER_GET_WORK();
        }
      } else {
        SCH_new_alternative(PREG, ANSWER_RESOLUTION);
        if (B != DepFr_leader_cp(LOCAL_top_dep_fr)) {
          /* not leader on that node */
          SCHEDULER_GET_WORK();
        }
      }
    } else
#endif /* YAPOR */
    {
      if (IS_BATCHED_GEN_CP(B)) {
        B->cp_ap = NULL;
        dprintf("LEADER_CP=%d\n", (int)DepFr_leader_cp(LOCAL_top_dep_fr));
        if (EQUAL_OR_YOUNGER_CP(B_FZ, B) && B != DepFr_leader_cp(LOCAL_top_dep_fr)) {
          /* not leader on that node */
          dprintf("not leader on that node\n");
          B = B->cp_b;
          goto fail;
        }
      } else {
        B->cp_ap = ANSWER_RESOLUTION;
        if (B != DepFr_leader_cp(LOCAL_top_dep_fr)) {
          /* not leader on that node */
          B = B->cp_b;
          dprintf("not a leader on that node 2\n");
          goto fail;
        }
      }
    }
    /* leader on that node */


  completion:
    INIT_PREFETCH()
    dep_fr_ptr dep_fr;
    ans_node_ptr ans_node;
    continuation_ptr next;
    
#ifdef YAPOR
#ifdef TIMESTAMP_CHECK
    long timestamp = 0;
#endif /* TIMESTAMP_CHECK */
    int entry_owners = 0;

    if (SCH_top_shared_cp(B)) {
#ifdef TIMESTAMP_CHECK
      timestamp = ++GLOBAL_timestamp;
#endif /* TIMESTAMP_CHECK */
      entry_owners = OrFr_owners(LOCAL_top_or_fr);
    }
#endif /* YAPOR */

    dprintf("checking deps\n");
    /* check for dependency frames with unconsumed answers */
    dep_fr = LOCAL_top_dep_fr;
    while (YOUNGER_CP(DepFr_cons_cp(dep_fr), B)) {
      LOCK(DepFr_lock(dep_fr));
      
#ifdef FDEBUG
      printSubgoalTriePath(stdout, SgFr_leaf(DepFr_sg_fr(dep_fr)), SgFr_tab_ent(DepFr_sg_fr(dep_fr)));
      dprintf("\n");
#endif
      
      ans_node = NULL;
      next = get_next_answer_continuation(dep_fr);
      
      if(next) {
        dprintf("UNCONSUMED ANSWERS!\n");
        /* dependency frame with unconsumed answers */
        ans_node = continuation_answer(next);
        DepFr_last_answer(dep_fr) = next;
      } else
        dprintf("EVERYTHING WAS CONSUMED!\n");
      
      if(ans_node != NULL) {
        if (B->cp_ap) {
#ifdef YAPOR
          if (YOUNGER_CP(DepFr_backchain_cp(dep_fr), B))
#endif /* YAPOR */
            DepFr_backchain_cp(dep_fr) = B;
	} else {
#ifdef YAPOR
          if (YOUNGER_CP(DepFr_backchain_cp(dep_fr), B->cp_b))
#endif /* YAPOR */
            DepFr_backchain_cp(dep_fr) = B->cp_b;
	}
        UNLOCK(DepFr_lock(dep_fr));

#ifdef OPTYAP_ERRORS
        if (PARALLEL_EXECUTION_MODE) {
          if (YOUNGER_CP(Get_LOCAL_top_cp(), Get_LOCAL_top_cp_on_stack())) {
            OPTYAP_ERROR_MESSAGE("YOUNGER_CP(LOCAL_top_cp, LOCAL_top_cp_on_stack) (completion)");
          } else {
            choiceptr aux_cp;
            aux_cp = DepFr_cons_cp(dep_fr);
            while (YOUNGER_CP(aux_cp, Get_LOCAL_top_cp_on_stack()))
              aux_cp = aux_cp->cp_b;
            if (aux_cp->cp_or_fr != DepFr_top_or_fr(dep_fr))
              OPTYAP_ERROR_MESSAGE("Error on DepFr_top_or_fr (completion)");
	  }
	}
#endif /* OPTYAP_ERRORS */
#ifdef YAPOR
        /* update shared nodes */
        if (YOUNGER_CP(Get_LOCAL_top_cp_on_stack(), Get_LOCAL_top_cp())) {
          or_fr_ptr or_frame = DepFr_top_or_fr(dep_fr);
          while (or_frame != LOCAL_top_or_fr) {
            LOCK_OR_FRAME(or_frame);
            BITMAP_insert(OrFr_members(or_frame), worker_id);
            BRANCH(worker_id, OrFr_depth(or_frame)) = 1;
            UNLOCK_OR_FRAME(or_frame);
            or_frame = OrFr_next(or_frame);
          }
          LOCAL_top_or_fr = DepFr_top_or_fr(dep_fr);
          Set_LOCAL_top_cp(GetOrFr_node(LOCAL_top_or_fr));
        }
#endif /* YAPOR */
#ifdef OPTYAP_ERRORS
        if (PARALLEL_EXECUTION_MODE) {
          if (YOUNGER_CP(Get_LOCAL_top_cp(), Get_LOCAL_top_cp_on_stack())) {
            OPTYAP_ERROR_MESSAGE("YOUNGER_CP(LOCAL_top_cp, LOCAL_top_cp_on_stack) (completion)");
          } else {
            choiceptr aux_cp;
            aux_cp = DepFr_cons_cp(dep_fr);
            while (aux_cp != Get_LOCAL_top_cp()) {
              if (YOUNGER_CP(Get_LOCAL_top_cp(), aux_cp)) {
                OPTYAP_ERROR_MESSAGE("LOCAL_top_cp not in branch (completion)");
                break;
              }
              if (EQUAL_OR_YOUNGER_CP(Get_LOCAL_top_cp_on_stack(), aux_cp)) {
                OPTYAP_ERROR_MESSAGE("shared frozen segments in branch (completion)");
                break;
              }
              aux_cp = aux_cp->cp_b;
            }
          }
	}
#endif /* OPTYAP_ERRORS */
        /* rebind variables, update registers, consume answer and procceed */
#ifdef TABLING_ERRORS
        if (EQUAL_OR_YOUNGER_CP(B, DepFr_cons_cp(dep_fr)))
          TABLING_ERROR_MESSAGE("EQUAL_OR_YOUNGER_CP(B, DepFr_cons_cp(dep_fr)) (completion)");
        if (B->cp_tr > DepFr_cons_cp(dep_fr)->cp_tr)
          TABLING_ERROR_MESSAGE("B->cp_tr > DepFr_cons_cp(dep_fr)->cp_tr (completion)");
#endif /* TABLING_ERRORS */
        rebind_variables(DepFr_cons_cp(dep_fr)->cp_tr, B->cp_tr);
#ifdef TABLING_ERRORS
        if (TR != B->cp_tr) {
          if(! IsPairTerm((CELL)TrailTerm(TR - 1)))
            TABLING_ERROR_MESSAGE("! IsPairTerm((CELL)TrailTerm(TR - 1)) (completion)");
          if ((tr_fr_ptr) RepPair((CELL)TrailTerm(TR - 1)) != B->cp_tr)
            TABLING_ERROR_MESSAGE("RepPair((CELL)TrailTerm(TR - 1)) != B->cp_tr (completion)");
	}
#endif /* TABLING_ERRORS */
        B = DepFr_cons_cp(dep_fr);
        TR = TR_FZ;
        if (TR != B->cp_tr)
          TRAIL_LINK(B->cp_tr);
        consume_answer_and_procceed(dep_fr, ans_node);
      }
      UNLOCK(DepFr_lock(dep_fr));
#ifdef TIMESTAMP_CHECK
      DepFr_timestamp(dep_fr) = timestamp;
#endif /* TIMESTAMP_CHECK */
      dep_fr = DepFr_next(dep_fr);
    }

    /* no dependency frames with unconsumed answers found */
#ifdef YAPOR
    if (SCH_top_shared_cp(B)) {
      if (entry_owners > 1) {
        /* more owners when we start looking for dependency frames with unconsumed answers */
        if (YOUNGER_CP(B_FZ, B)) {
          suspend_branch();
          /* check for suspension frames to be resumed */
          while (YOUNGER_CP(GetOrFr_node(LOCAL_top_susp_or_fr), Get_LOCAL_top_cp())) {
            or_fr_ptr susp_or_fr;
            susp_fr_ptr resume_fr;
            susp_or_fr = LOCAL_top_susp_or_fr;
            LOCK_OR_FRAME(susp_or_fr);
#ifdef TIMESTAMP_CHECK
            resume_fr = suspension_frame_to_resume(susp_or_fr, timestamp);
#else
            resume_fr = suspension_frame_to_resume(susp_or_fr);
#endif /* TIMESTAMP_CHECK */
	    if (resume_fr) {
              if (OrFr_suspensions(susp_or_fr) == NULL) {
                LOCAL_top_susp_or_fr = OrFr_nearest_suspnode(susp_or_fr);
                OrFr_nearest_suspnode(susp_or_fr) = susp_or_fr;
              }
              UNLOCK_OR_FRAME(susp_or_fr);
              rebind_variables(GetOrFr_node(susp_or_fr)->cp_tr, B->cp_tr);
              resume_suspension_frame(resume_fr, susp_or_fr);
              B = Get_LOCAL_top_cp();
              SET_BB(B_FZ);
              TR = TR_FZ;
              TRAIL_LINK(B->cp_tr);
              goto completion;
            }
            LOCAL_top_susp_or_fr = OrFr_nearest_suspnode(susp_or_fr);
            OrFr_nearest_suspnode(susp_or_fr) = NULL;
            UNLOCK_OR_FRAME(susp_or_fr);
          }
        }
      } else {
        /* unique owner */
        if (frame_with_suspensions_not_collected(LOCAL_top_or_fr))
          collect_suspension_frames(LOCAL_top_or_fr);
        /* check for suspension frames to be resumed */
        while (EQUAL_OR_YOUNGER_CP(GetOrFr_node(LOCAL_top_susp_or_fr), Get_LOCAL_top_cp())) {
          or_fr_ptr susp_or_fr;
          susp_fr_ptr resume_fr;
          susp_or_fr = LOCAL_top_susp_or_fr;
#ifdef TIMESTAMP_CHECK
          resume_fr = suspension_frame_to_resume(susp_or_fr, timestamp);
#else
          resume_fr = suspension_frame_to_resume(susp_or_fr);
#endif /* TIMESTAMP_CHECK */
          if (resume_fr) {
            if (OrFr_suspensions(susp_or_fr) == NULL) {
              LOCAL_top_susp_or_fr = OrFr_nearest_suspnode(susp_or_fr);
              OrFr_nearest_suspnode(susp_or_fr) = susp_or_fr;
            }
            if (YOUNGER_CP(B_FZ, B)) {
              suspend_branch();
            }
            rebind_variables(GetOrFr_node(susp_or_fr)->cp_tr, B->cp_tr);
            resume_suspension_frame(resume_fr, susp_or_fr);
            B = Get_LOCAL_top_cp();
            SET_BB(B_FZ);
            TR = TR_FZ;
            TRAIL_LINK(B->cp_tr);
            goto completion;
          }
          LOCAL_top_susp_or_fr = OrFr_nearest_suspnode(susp_or_fr);
          OrFr_nearest_suspnode(susp_or_fr) = NULL;
        }
        /* complete all */
        public_completion();
      }
#ifdef TABLING_ERRORS
      if (TR != B->cp_tr) {
        if(! IsPairTerm((CELL)TrailTerm(TR - 1)))
          TABLING_ERROR_MESSAGE("! IsPairTerm((CELL)TrailTerm(TR - 1)) (completion)");
        if ((tr_fr_ptr) RepPair((CELL)TrailTerm(TR - 1)) != B->cp_tr)
          TABLING_ERROR_MESSAGE("RepPair((CELL)TrailTerm(TR - 1)) != B->cp_tr (completion)");
      }
#endif /* TABLING_ERRORS */
      if (B == DepFr_leader_cp(LOCAL_top_dep_fr)) {
        /*  B is a generator-consumer node  */
        /* never here if batched scheduling */
        
#ifdef TABLING_ERRORS
	      if (IS_BATCHED_GEN_CP(B))
	        TABLING_ERROR_MESSAGE("IS_BATCHED_GEN_CP(B) (completion)");
#endif /* TABLING_ERRORS */

        TR = B->cp_tr;
        SET_BB(B);
        LOCK_OR_FRAME(LOCAL_top_or_fr);
        LOCK(DepFr_lock(LOCAL_top_dep_fr));
        
        next = get_next_answer_continuation(LOCAL_top_dep_fr);
        
        if(next) {
          /* unconsumed answer */
          UNLOCK_OR_FRAME(LOCAL_top_or_fr);
          
          ans_node = continuation_answer(next);
          DepFr_last_answer(LOCAL_top_dep_fr) = next;
          UNLOCK(DepFr_lock(LOCAL_top_dep_fr));
          consume_answer_and_procceed(LOCAL_top_dep_fr, ans_node);
        }

        /* no unconsumed answers */
        UNLOCK(DepFr_lock(LOCAL_top_dep_fr));
        if (OrFr_owners(LOCAL_top_or_fr) > 1) {
          /* more owners -> move up one node */
          Set_LOCAL_top_cp_on_stack( GetOrFr_node(OrFr_next_on_stack(LOCAL_top_or_fr)) );
          BITMAP_delete(OrFr_members(LOCAL_top_or_fr), worker_id);
          OrFr_owners(LOCAL_top_or_fr)--;
          LOCAL_top_dep_fr = DepFr_next(LOCAL_top_dep_fr);
          UNLOCK_OR_FRAME(LOCAL_top_or_fr);
          if (LOCAL_top_sg_fr && Get_LOCAL_top_cp() == SgFr_choice_point(LOCAL_top_sg_fr)) {
            LOCAL_top_sg_fr = SgFr_next(LOCAL_top_sg_fr);
          }
          SCH_update_local_or_tops();
          CUT_reset_prune_request();
          adjust_freeze_registers();
          goto shared_fail;
        } else {
          /* free top dependency frame --> get work */
          OrFr_alternative(LOCAL_top_or_fr) = NULL;
          UNLOCK_OR_FRAME(LOCAL_top_or_fr);
          dep_fr = DepFr_next(LOCAL_top_dep_fr);
          FREE_DEPENDENCY_FRAME(LOCAL_top_dep_fr);
          LOCAL_top_dep_fr = dep_fr;
          adjust_freeze_registers();
          SCHEDULER_GET_WORK();
        }
      }
      /* goto getwork */
      PREG = B->cp_ap;
      PREFETCH_OP(PREG);
      TR = B->cp_tr;
      SET_BB(B);
      GONext();
    } else
#endif /* YAPOR */
    {
      /* complete all */
      sg_fr_ptr sg_fr;

#ifdef DETERMINISTIC_TABLING
      if (IS_DET_GEN_CP(B))
	      sg_fr = DET_GEN_CP(B)->cp_sg_fr;
      else	 
#endif /* DETERMINISTIC_TABLING */
	      sg_fr = GEN_CP(B)->cp_sg_fr;
      
      private_completion(sg_fr);
      
      if (IS_BATCHED_GEN_CP(B)) {
        /* batched scheduling -> backtrack */
        B = B->cp_b;
        dprintf("Backtrack\n");
        SET_BB(PROTECT_FROZEN_B(B));
        goto fail;
      } else {
        /* this is local scheduling, we can now complete and return answers */
        /* subgoal completed */
        
        if (SgFr_has_no_answers(sg_fr)) {
          /* no answers --> fail */
          B = B->cp_b;
          SET_BB(PROTECT_FROZEN_B(B));
          goto fail;
        }
        
#ifdef TABLING_ERRORS
        if (TR != B->cp_tr) {
          if(! IsPairTerm((CELL)TrailTerm(TR - 1)))
            TABLING_ERROR_MESSAGE("! IsPairTerm((CELL)TrailTerm(TR - 1)) (completion)");
          if ((tr_fr_ptr) RepPair((CELL)TrailTerm(TR - 1)) != B->cp_tr)
            TABLING_ERROR_MESSAGE("RepPair((CELL)TrailTerm(TR - 1)) != B->cp_tr (completion)");
        }
#endif /* TABLING_ERRORS */
        pop_generator_node(SgFr_arity(sg_fr));

        switch(SgFr_type(sg_fr)) {
          case VARIANT_PRODUCER_SFT:
          case SUBSUMPTIVE_PRODUCER_SFT:
            {
              check_yes_answer_no_unlock(sg_fr);
                
              limit_tabling_do_remove_sf(sg_fr);
                
              tab_ent_ptr tab_ent = SgFr_tab_ent(sg_fr);
                
              if(TabEnt_is_load(tab_ent)) {
                load_answers_from_sf_no_unlock(sg_fr, tab_ent, CONSUME_VARIANT_ANSWER, LOAD_ANSWER, YENV);
              } else {
                LOCK(SgFr_lock(sg_fr));
                ensure_subgoal_is_compiled(sg_fr);
                exec_subgoal_compiled_trie(sg_fr);
              }
            }
            break;
          case GROUND_PRODUCER_SFT:
            {
              check_yes_answer_no_unlock(sg_fr);
              
              tab_ent_ptr tab_ent = SgFr_tab_ent(sg_fr);
              
              if(TabEnt_is_load(tab_ent)) {
                load_answers_from_sf_no_unlock(sg_fr, tab_ent, CONSUME_SUBSUMPTIVE_ANSWER, LOAD_CONS_ANSWER, YENV);
              } else {
                exec_ground_trie(tab_ent);
              }
            }
            break;
          default: break;
	      }
      }
    }
  END_PREFETCH()
  ENDBOp();
