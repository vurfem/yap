/**********************************************************************
                                                               
                       The OPTYap Prolog system                
  OPTYap extends the Yap Prolog system to support or-parallel tabling
                                                               
  Copyright:   R. Rocha and NCC - University of Porto, Portugal
  File:        tab.macros.h
  version:     $Id: tab.macros.h,v 1.22 2008-05-23 18:28:58 ricroc Exp $   
                                                                     
**********************************************************************/

/* ------------------ **
**      Includes      **
** ------------------ */

#include <stdlib.h>
#if HAVE_STRING_H
#include <string.h>
#endif
#include "opt.mavar.h"
#include "tab.utils.h"
#include "tab.blocks.h"
#include "Yatom.h"


/* -------------------- **
**      Prototypes      **
** -------------------- */

STD_PROTO(static inline void adjust_freeze_registers, (void));
STD_PROTO(static inline void mark_as_completed, (sg_fr_ptr));
STD_PROTO(static inline void unbind_variables, (tr_fr_ptr, tr_fr_ptr));
STD_PROTO(static inline void rebind_variables, (tr_fr_ptr, tr_fr_ptr));
STD_PROTO(static inline void restore_bindings, (tr_fr_ptr, tr_fr_ptr));

STD_PROTO(static inline void free_subgoal_trie_hash_chain, (sg_hash_ptr));
STD_PROTO(static inline void free_answer_trie_hash_chain, (ans_hash_ptr));

STD_PROTO(static inline void free_answer_trie_node, (ans_node_ptr));
STD_PROTO(static inline void free_subgoal_trie_node, (sg_node_ptr));

STD_PROTO(static inline void free_variant_subgoal_data, (sg_fr_ptr, int));

STD_PROTO(static void abolish_incomplete_variant_subgoal, (sg_fr_ptr sg_fr));
STD_PROTO(static inline void abolish_incomplete_producer_subgoal, (sg_fr_ptr sg_fr));
STD_PROTO(static inline void abolish_incomplete_subgoals, (choiceptr));

STD_PROTO(static inline continuation_ptr get_next_answer_continuation, (dep_fr_ptr dep_fr));
STD_PROTO(static inline int is_new_generator_call, (sg_fr_ptr));
STD_PROTO(static inline int is_new_consumer_call, (sg_fr_ptr));
STD_PROTO(static inline choiceptr freeze_current_cp, (void));
STD_PROTO(static inline void resume_frozen_cp, (choiceptr));
STD_PROTO(static inline void abolish_all_frozen_cps, (void));

STD_PROTO(static inline void free_node_list, (node_list_ptr));

#ifdef YAPOR
STD_PROTO(static inline void pruning_over_tabling_data_structures, (void));
STD_PROTO(static inline void collect_suspension_frames, (or_fr_ptr));
#ifdef TIMESTAMP_CHECK
STD_PROTO(static inline susp_fr_ptr suspension_frame_to_resume, (or_fr_ptr, long));
#else
STD_PROTO(static inline susp_fr_ptr suspension_frame_to_resume, (or_fr_ptr));
#endif /* TIMESTAMP_CHECK */
#endif /* YAPOR */

#ifdef TABLING_INNER_CUTS
STD_PROTO(static inline void CUT_store_tg_answer, (or_fr_ptr, ans_node_ptr, choiceptr, int));
STD_PROTO(static inline tg_sol_fr_ptr CUT_store_tg_answers, (or_fr_ptr, tg_sol_fr_ptr, int));
STD_PROTO(static inline void CUT_validate_tg_answers, (tg_sol_fr_ptr));
STD_PROTO(static inline void CUT_join_tg_solutions, (tg_sol_fr_ptr *, tg_sol_fr_ptr));
STD_PROTO(static inline void CUT_join_solution_frame_tg_answers, (tg_sol_fr_ptr));
STD_PROTO(static inline void CUT_join_solution_frames_tg_answers, (tg_sol_fr_ptr));
STD_PROTO(static inline void CUT_free_tg_solution_frame, (tg_sol_fr_ptr));
STD_PROTO(static inline void CUT_free_tg_solution_frames, (tg_sol_fr_ptr));
STD_PROTO(static inline tg_sol_fr_ptr CUT_prune_tg_solution_frames, (tg_sol_fr_ptr, int));
#endif /* TABLING_INNER_CUTS */



/* ----------------- **
**      Defines      **
** ----------------- */

#define SHOW_MODE_STRUCTURE     0
#define SHOW_MODE_STATISTICS    1
#define TRAVERSE_TYPE_SUBGOAL   0
#define TRAVERSE_TYPE_ANSWER    1
#define TRAVERSE_MODE_NORMAL    0
#define TRAVERSE_MODE_FLOAT     1
#define TRAVERSE_MODE_FLOAT2    2
#define TRAVERSE_MODE_FLOAT_END 3
#define TRAVERSE_MODE_LONG      4
#define TRAVERSE_MODE_LONG_END  5
/* do not change order !!! */
#define TRAVERSE_POSITION_NEXT  0
#define TRAVERSE_POSITION_FIRST 1
#define TRAVERSE_POSITION_LAST  2



/* ----------------------- **
**     Tabling Macros      **
** ----------------------- */

#define NORM_CP(CP)                 ((choiceptr)(CP))
#define GEN_CP(CP)                  ((struct generator_choicept *)(CP))
#define CONS_CP(CP)                 ((struct consumer_choicept *)(CP))
#define LOAD_CP(CP)                 ((struct loader_choicept *)(CP))
#define HASH_CP(CP)                 ((struct hash_choicept *)(CP))
#ifdef DETERMINISTIC_TABLING
#define DET_GEN_CP(CP)              ((struct deterministic_generator_choicept *)(CP))
#define IS_DET_GEN_CP(CP)           (*(CELL*)(DET_GEN_CP(CP) + 1) <= MAX_TABLE_VARS)
#define IS_BATCHED_NORM_GEN_CP(CP)  (GEN_CP(CP)->cp_dep_fr == NULL)
#define IS_BATCHED_GEN_CP(CP)       (IS_DET_GEN_CP(CP) || IS_BATCHED_NORM_GEN_CP(CP))
#else
#define IS_BATCHED_GEN_CP(CP)       (GEN_CP(CP)->cp_dep_fr == NULL)
#endif /* DETERMINISTIC_TABLING */

/* code related macros */
#define CODE_TABLE_ENTRY(CODE) ((CODE)->u.Otapl.te)
#define CODE_ARITY(CODE)       ((CODE)->u.Otapl.s)
#define CALL_ARGUMENTS() (XREGS + 1)


#define STACK_NOT_EMPTY(STACK, STACK_BASE)  STACK != STACK_BASE
#define STACK_PUSH_UP(ITEM, STACK)          *--STACK = (CELL)(ITEM)
#define STACK_POP_DOWN(STACK)               *STACK++
#define STACK_PUSH_DOWN(ITEM, STACK)        *STACK++ = (CELL)(ITEM)
#define STACK_POP_UP(STACK)                 *--STACK
#ifdef YAPOR
#define STACK_CHECK_EXPAND(STACK, STACK_LIMIT, STACK_BASE)                              \
        if (STACK_LIMIT >= STACK) {                                                     \
	  Yap_Error(INTERNAL_ERROR, TermNil, "stack full (STACK_CHECK_EXPAND)"); \
        }

/* should work for now */
#define STACK_CHECK_EXPAND1(STACK, STACK_LIMIT, STACK_BASE) STACK_CHECK_EXPAND(STACK, STACK_LIMIT, STACK_BASE)

#else
#define STACK_CHECK_EXPAND(STACK, STACK_LIMIT, STACK_BASE)                              \
        if (STACK_LIMIT >= STACK) {                                                     \
          void *old_top;                                                                \
          UInt diff;                                                                    \
          CELL *NEW_STACK;                                                              \
          INFORMATION_MESSAGE("Expanding trail in 64 Kbytes");                          \
          old_top = Yap_TrailTop;                                                       \
          if (!Yap_growtrail(64 * 1024L, TRUE)) {                                       \
            Yap_Error(OUT_OF_TRAIL_ERROR, TermNil, "stack full (STACK_CHECK_EXPAND)");  \
            P = FAILCODE;                                                               \
          } else {                                                                      \
            diff = (void *)Yap_TrailTop - old_top;                                      \
            NEW_STACK = (CELL *)((void *)STACK + diff);                                 \
            memmove((void *)NEW_STACK, (void *)STACK, old_top - (void *)STACK);         \
            STACK = NEW_STACK;                                                          \
            STACK_BASE = (CELL *)((void *)STACK_BASE + diff);                           \
          }                                                                             \
        }
#endif /* YAPOR */


#ifdef GLOBAL_TRIE
#define INCREMENT_GLOBAL_TRIE_REFS(NODE)                                                          \
        { register gt_node_ptr gt_node = NODE;                                                    \
	  TrNode_child(gt_node) = (gt_node_ptr) ((unsigned long int) TrNode_child(gt_node) + 1);  \
	}
#define DECREMENT_GLOBAL_TRIE_REFS(NODE)                                                          \
        { register gt_node_ptr gt_node = NODE;                                                    \
	  TrNode_child(gt_node) = (gt_node_ptr) ((unsigned long int) TrNode_child(gt_node) - 1);  \
          if (TrNode_child(gt_node) == 0)                                                         \
            free_global_trie_branch(gt_node);                                                     \
	}
#else
#define INCREMENT_GLOBAL_TRIE_REFS(NODE)
#define DECREMENT_GLOBAL_TRIE_REFS(NODE)
#endif /* GLOBAL_TRIE */
#define TAG_AS_ANSWER_LEAF_NODE(NODE)     TrNode_node_type(NODE) |= LEAF_NT
#define IS_ANSWER_LEAF_NODE(NODE)         (TrNode_node_type(NODE) & LEAF_NT)


/* LowTagBits is 3 for 32 bit-machines and 7 for 64 bit-machines */
#define NumberOfLowTagBits         (LowTagBits == 3 ? 2 : 3)

#define NEW_TRIEVAR_TAG     0x100000
#define TRIEVAR_INDEX_MASK  0xfffff

#define MakeTableVarTerm(INDEX)     (INDEX << NumberOfLowTagBits)
#define MakeNewTableVarTerm(INDEX)  (MakeTableVarTerm(INDEX) | NEW_TRIEVAR_TAG)
#define IsNewTableVarTerm(TERM)	    (TERM & NEW_TRIEVAR_TAG)
#define VarIndexOfTableTerm(TERM)   (((unsigned int) TERM & TRIEVAR_INDEX_MASK) >> NumberOfLowTagBits)
#define VarIndexOfTerm(TERM)                                               \
        ((((CELL) TERM) - GLOBAL_table_var_enumerator(0)) / sizeof(CELL))
#define IsTableVarTerm(TERM)                                               \
        ((CELL) TERM) >= GLOBAL_table_var_enumerator(0) &&                 \
        ((CELL) TERM) <= GLOBAL_table_var_enumerator(MAX_TABLE_VARS - 1)
#ifdef TRIE_COMPACT_PAIRS
#define PairTermMark        NULL
#define CompactPairInit     AbsPair((Term *) 0)
#define CompactPairEndTerm  AbsPair((Term *) (LowTagBits + 1))
#define CompactPairEndList  AbsPair((Term *) (2*(LowTagBits + 1)))
#endif /* TRIE_COMPACT_PAIRS */

#define EncodedLongFunctor  AbsAppl((Term *)FunctorLongInt)
#define EncodedFloatFunctor AbsAppl((Term *)FunctorDouble)

#define GET_HASH_SYMBOL(DATA, FLAGS) \
          (IS_LONG_INT_FLAG(FLAGS) ? (Term)*(Int *)(DATA) : \
            (IS_FLOAT_FLAG(FLAGS) ? (Term)*(Float *)(DATA) : (Term)(DATA)))

#define HASH_TABLE_LOCK(NODE)  ((((unsigned long int) NODE) >> 5) & (TABLE_LOCK_BUCKETS - 1))
#define LOCK_TABLE(NODE)         LOCK(GLOBAL_table_lock(HASH_TABLE_LOCK(NODE)))
#define UNLOCK_TABLE(NODE)     UNLOCK(GLOBAL_table_lock(HASH_TABLE_LOCK(NODE)))

#define frame_with_suspensions_not_collected(OR_FR)  (OrFr_nearest_suspnode(OR_FR) == NULL)

#ifdef YAPOR
#define find_dependency_node(SG_FR, LEADER_CP, DEP_ON_STACK)                      \
        if (SgFr_gen_worker(SG_FR) == worker_id) {                                \
          LEADER_CP = SgFr_choice_point(SG_FR);                                         \
          DEP_ON_STACK = TRUE;                                                    \
        } else {                                                                  \
          or_fr_ptr aux_or_fr = SgFr_gen_top_or_fr(SG_FR);                        \
          while (! BITMAP_member(OrFr_members(aux_or_fr), worker_id))             \
            aux_or_fr = OrFr_next(aux_or_fr);                                     \
          LEADER_CP = GetOrFr_node(aux_or_fr);                                    \
          DEP_ON_STACK = (LEADER_CP == SgFr_choice_point(SG_FR));                       \
        }
#define find_leader_node(LEADER_CP, DEP_ON_STACK)                                 \
        { dep_fr_ptr chain_dep_fr = LOCAL_top_dep_fr;                             \
          while (YOUNGER_CP(DepFr_cons_cp(chain_dep_fr), LEADER_CP)) {            \
            if (LEADER_CP == DepFr_leader_cp(chain_dep_fr)) {                     \
              DEP_ON_STACK |= DepFr_leader_dep_is_on_stack(chain_dep_fr);         \
              break;                                                              \
            } else if (YOUNGER_CP(LEADER_CP, DepFr_leader_cp(chain_dep_fr))) {    \
              LEADER_CP = DepFr_leader_cp(chain_dep_fr);                          \
              DEP_ON_STACK = DepFr_leader_dep_is_on_stack(chain_dep_fr);          \
              break;                                                              \
            }                                                                     \
            chain_dep_fr = DepFr_next(chain_dep_fr);                              \
          }                                                                       \
	}
#else

#ifdef TABLING_CALL_SUBSUMPTION
#define find_dependency_node(SG_FR, LEADER_CP, DEP_ON_STACK)                      \
        DEP_ON_STACK = TRUE;                                                      \
        switch(SgFr_type(SG_FR)) {                                                \
          case VARIANT_PRODUCER_SFT:                                              \
          case SUBSUMPTIVE_PRODUCER_SFT:                                          \
          case GROUND_PRODUCER_SFT:                                               \
            LEADER_CP = SgFr_choice_point(SG_FR);                                 \
            break;                                                                \
          case SUBSUMED_CONSUMER_SFT:                                             \
            LEADER_CP = SgFr_choice_point(SgFr_producer((subcons_fr_ptr)(SG_FR)));  \
            break;                                                                  \
          case GROUND_CONSUMER_SFT:                                               \
            LEADER_CP = SgFr_choice_point(SgFr_producer((grounded_sf_ptr)(SG_FR))); \
            break;                                                                  \
          default:                                                                \
            LEADER_CP = NULL;                                                     \
        }
#else
#define find_dependency_node(SG_FR, LEADER_CP, DEP_ON_STACK)                      \
        LEADER_CP = SgFr_choice_point(SG_FR);                                           \
        DEP_ON_STACK = TRUE                                                       
#endif /* TABLING_CALL_SUBSUMPTION */

#define find_leader_node(LEADER_CP, DEP_ON_STACK)                                 \
        { dep_fr_ptr chain_dep_fr = LOCAL_top_dep_fr;                             \
          while (YOUNGER_CP(DepFr_cons_cp(chain_dep_fr), LEADER_CP)) {            \
            if (EQUAL_OR_YOUNGER_CP(LEADER_CP, DepFr_leader_cp(chain_dep_fr))) {  \
              LEADER_CP = DepFr_leader_cp(chain_dep_fr);                          \
              break;                                                              \
            }                                                                     \
            chain_dep_fr = DepFr_next(chain_dep_fr);                              \
          }                                                                       \
          dprintf("LEADER_CP=%d\n", (int)LEADER_CP);                                    \
	      }
#endif /* YAPOR */


#ifdef YAPOR
#ifdef TIMESTAMP
#define DepFr_init_timestamp_field(DEP_FR)  DepFr_timestamp(DEP_FR) = 0
#else
#define DepFr_init_timestamp_field(DEP_FR)
#endif /* TIMESTAMP */
#define YAPOR_SET_LOAD(CP_PTR)  SCH_set_load(CP_PTR)
#define SgFr_init_yapor_fields(SG_FR)                             \
        SgFr_gen_worker(SG_FR) = worker_id;                       \
        SgFr_gen_top_or_fr(SG_FR) = LOCAL_top_or_fr
#define DepFr_init_yapor_fields(DEP_FR, DEP_ON_STACK, TOP_OR_FR)  \
        DepFr_leader_dep_is_on_stack(DEP_FR) = DEP_ON_STACK;      \
        DepFr_top_or_fr(DEP_FR) = TOP_OR_FR;                      \
        DepFr_init_timestamp_field(DEP_FR)
#else
#define YAPOR_SET_LOAD(CP_PTR)
#define SgFr_init_yapor_fields(SG_FR)
#define DepFr_init_yapor_fields(DEP_FR, DEP_ON_STACK, TOP_OR_FR)
#endif /* YAPOR */


#ifdef TABLE_LOCK_AT_ENTRY_LEVEL
#define TabEnt_init_lock_field(TAB_ENT)  INIT_LOCK(TabEnt_lock(TAB_ENT))
#define SgHash_init_next_field(HASH, TAB_ENT)          \
        Hash_next(HASH) = TabEnt_hash_chain(TAB_ENT);  \
        TabEnt_hash_chain(TAB_ENT) = HASH
#define AnsHash_init_next_field(HASH, SG_FR)       \
        Hash_next(HASH) = (ans_hash_ptr)SgFr_hash_chain(SG_FR);  \
        SgFr_hash_chain(SG_FR) = HASH
#else
#define TabEnt_init_lock_field(TAB_ENT)
#define SgHash_init_next_field(HASH, TAB_ENT)          \
        LOCK(TabEnt_lock(TAB_ENT));                    \
        Hash_next(HASH) = TabEnt_hash_chain(TAB_ENT);  \
        TabEnt_hash_chain(TAB_ENT) = HASH;             \
        UNLOCK(TabEnt_lock(TAB_ENT))
#define AnsHash_init_next_field(HASH, SG_FR)       \
        LOCK(SgFr_lock(SG_FR));                    \
        Hash_next(HASH) = (ans_hash_ptr)SgFr_hash_chain(SG_FR);  \
        SgFr_hash_chain(SG_FR) = (ans_node_ptr)HASH;             \
        UNLOCK(SgFr_lock(SG_FR))
#endif /* TABLE_LOCK_AT_ENTRY_LEVEL */
#ifdef TABLE_LOCK_AT_NODE_LEVEL
#define TrNode_init_lock_field(NODE)  INIT_LOCK(TrNode_lock(NODE))
#else
#define TrNode_init_lock_field(NODE)
#endif /* TABLE_LOCK_AT_NODE_LEVEL */


#define new_suspension_frame(SUSP_FR, TOP_OR_FR_ON_STACK, TOP_DEP, TOP_SG,         \
                             H_REG, B_REG, TR_REG, H_SIZE, B_SIZE, TR_SIZE)        \
        ALLOC_SUSPENSION_FRAME(SUSP_FR);                                           \
        SuspFr_top_or_fr_on_stack(SUSP_FR) = TOP_OR_FR_ON_STACK;                   \
        SuspFr_top_dep_fr(SUSP_FR) = TOP_DEP;                                      \
        SuspFr_top_sg_fr(SUSP_FR) = TOP_SG;                                        \
        SuspFr_global_reg(SUSP_FR) = (void *) (H_REG);                             \
        SuspFr_local_reg(SUSP_FR) = (void *) (B_REG);                              \
        SuspFr_trail_reg(SUSP_FR) = (void *) (TR_REG);                             \
        ALLOC_BLOCK(SuspFr_global_start(SUSP_FR), H_SIZE + B_SIZE + TR_SIZE);      \
        SuspFr_local_start(SUSP_FR) = SuspFr_global_start(SUSP_FR) + H_SIZE;       \
        SuspFr_trail_start(SUSP_FR) = SuspFr_local_start(SUSP_FR) + B_SIZE;        \
        SuspFr_global_size(SUSP_FR) = H_SIZE;                                      \
        SuspFr_local_size(SUSP_FR) = B_SIZE;                                       \
        SuspFr_trail_size(SUSP_FR) = TR_SIZE;                                      \
        memcpy(SuspFr_global_start(SUSP_FR), SuspFr_global_reg(SUSP_FR), H_SIZE);  \
        memcpy(SuspFr_local_start(SUSP_FR), SuspFr_local_reg(SUSP_FR), B_SIZE);    \
        memcpy(SuspFr_trail_start(SUSP_FR), SuspFr_trail_reg(SUSP_FR), TR_SIZE)
        
#define add_answer_trie_subgoal_frame(SG_FR)      \
        { register ans_node_ptr ans_node;         \
          new_root_answer_trie_node(ans_node);    \
          SgFr_answer_trie(SG_FR) = ans_node;     \
        }
        
#define new_basic_subgoal_frame(SG_FR, CODE, LEAF, TYPE, ALLOC_FN) \
        { ALLOC_FN(SG_FR);                                         \
          INIT_LOCK(SgFr_lock(SG_FR));                             \
          SgFr_leaf(SG_FR) = LEAF;                                 \
          TrNode_sg_fr(LEAF) = (sg_node_ptr)(SG_FR);               \
          SgFr_type(SG_FR) = TYPE;                                 \
          SgFr_code(SG_FR) = CODE;                                 \
          SgFr_state(SG_FR) = ready;                               \
          SgFr_first_answer(SG_FR) = NULL;                         \
          SgFr_last_answer(SG_FR) = NULL;                          \
        }
        
#define new_variant_subgoal_frame(SG_FR, CODE, LEAF)  { \
        new_basic_subgoal_frame(SG_FR, CODE, LEAF,                \
          VARIANT_PRODUCER_SFT, ALLOC_VARIANT_SUBGOAL_FRAME);     \
        add_answer_trie_subgoal_frame(SG_FR);                     \
    }

#define init_subgoal_frame(SG_FR)                                  \
        { SgFr_init_yapor_fields(SG_FR);                           \
          SgFr_state(SG_FR) = evaluating;                          \
          SgFr_next(SG_FR) = LOCAL_top_sg_fr;                      \
          LOCAL_top_sg_fr = SG_FR;                                 \
	      }

#define SgFr_has_real_answers(SG_FR)                                      \
  (SgFr_first_answer(SG_FR) &&                                            \
    continuation_answer(SgFr_first_answer(SG_FR)) != SgFr_answer_trie(SG_FR))

#define SgFr_has_yes_answer(SG_FR)                                        \
    (SgFr_first_answer(SG_FR) &&                                          \
      continuation_answer(SgFr_first_answer(SG_FR)) == SgFr_answer_trie(SG_FR))
      
#define SgFr_has_no_answers(SG_FR)  SgFr_first_answer(SG_FR) == NULL

#ifdef TABLING_ANSWER_LIST

#define continuation_next(X)      NodeList_next(X)
#define continuation_has_next(X)  NodeList_next(X)
#define continuation_answer(X)    NodeList_node(X)

#define free_answer_continuation(CONT)  free_node_list(CONT)

#define push_new_answer_set(ANS, FIRST, LAST)       \
    { continuation_ptr new_list;                    \
      ALLOC_NODE_LIST(new_list);                    \
      NodeList_node(new_list) = (ans_node_ptr)ANS;  \
      NodeList_next(new_list) = NULL;               \
      if((FIRST) == NULL)                           \
        FIRST = new_list;                           \
      else                                          \
        NodeList_next(LAST) = new_list;             \
      LAST = new_list;                              \
    }

#define join_answers_subgoal_frame(SG_FR, FIRST, LAST) {  \
  if(SgFr_has_no_answers(SG_FR))                          \
    SgFr_first_answer(SG_FR) = FIRST;                     \
  else                                                    \
    NodeList_next(SgFr_last_answer(SG_FR)) = FIRST;       \
  SgFr_last_answer(SG_FR) = LAST;                         \
}

#define CONSUMER_DEFAULT_LAST_ANSWER(SG_FR, DEP_FR)                   \
  ((unsigned long int) (SG_FR) +                                      \
   (unsigned long int) (&SgFr_first_answer((sg_fr_ptr)(DEP_FR))) -    \
   (unsigned long int) (&NodeList_next((node_list_ptr)(DEP_FR))))

#elif defined(TABLING_ANSWER_CHILD)

#define continuation_has_next(X)  TrNode_child(X)
#define continuation_next(X)      TrNode_child(X)
#define continuation_answer(X)    (X)

#define push_new_answer_set(ANS, FIRST, LAST) { \
  if((FIRST) == NULL)                           \
    FIRST = ANS;                                \
  else                                          \
    TrNode_child(LAST) = ANS;                   \
  LAST = ANS;                                   \
}

#define join_answers_subgoal_frame(SG_FR, FIRST, LAST) {  \
  if(SgFr_has_no_answers(SG_FR))                          \
    SgFr_first_answer(SG_FR) = FIRST;                     \
  else                                                    \
    TrNode_child(SgFr_last_answer(SG_FR)) = FIRST;        \
  SgFr_last_answer(SG_FR) = LAST;                         \
}

#define free_answer_continuation(CONT)

#define CONSUMER_DEFAULT_LAST_ANSWER(SG_FR, DEP_FR)                   \
  ((unsigned long int) (SG_FR) +                                      \
   (unsigned long int) (&SgFr_first_answer((sg_fr_ptr)(DEP_FR))) -    \
   (unsigned long int) (&TrNode_child((ans_node_ptr)(DEP_FR))))

#elif defined(TABLING_ANSWER_BLOCKS)

#define ANSWER_BLOCK_SIZE 15

#define free_answer_continuation(CONT)        blocks_free(CONT, ANSWER_BLOCK_SIZE)
#define continuation_answer(X)                (*(X))
#define push_new_answer_set(ANS, FIRST, LAST) block_push(ANS, FIRST, LAST, ANSWER_BLOCK_SIZE, continuation_ptr)

static inline continuation_ptr
continuation_next(continuation_ptr cont)
{
  if(IS_BLOCK_TAG(cont))
    return *(continuation_ptr*)UNTAG_BLOCK_MASK(cont);
    
  return (continuation_ptr)block_get_next((void**)cont);
}

static inline int
continuation_has_next(continuation_ptr cont)
{
  if(IS_BLOCK_TAG(cont))
    return (int)*(continuation_ptr*)UNTAG_BLOCK_MASK(cont);
  
  return block_has_next(cont);
}

static inline void
join_answers_subgoal_frame(sg_fr_ptr sg_fr, continuation_ptr first, continuation_ptr last)
{
  if(SgFr_has_no_answers(sg_fr)) {
    SgFr_first_answer(sg_fr) = first;
    SgFr_last_answer(sg_fr) = last;
  } else {
    continuation_ptr ptr = first;
    
    while(TRUE) {
      block_push(*ptr, SgFr_first_answer(sg_fr),
          SgFr_last_answer(sg_fr), ANSWER_BLOCK_SIZE, continuation_ptr);
      
      if(ptr == last)
        break;
      
      ++ptr;
      
      if(IS_BLOCK_TAG(*ptr))
        ptr = (continuation_ptr)UNTAG_BLOCK_MASK(*ptr);
    }
    
    blocks_free(first, ANSWER_BLOCK_SIZE);
  }
}

#define CONSUMER_DEFAULT_LAST_ANSWER(SG_FR, DEP_FR) TAG_BLOCK_MASK(&SgFr_first_answer(SG_FR))
                 
#endif /* TABLING_ANSWER_LIST */


#define new_dependency_frame(DEP_FR, DEP_ON_STACK, TOP_OR_FR, LEADER_CP, CONS_CP, SG_FR, NEXT)         \
        ALLOC_DEPENDENCY_FRAME(DEP_FR);                                                                \
        INIT_LOCK(DepFr_lock(DEP_FR));                                                                 \
        DepFr_init_yapor_fields(DEP_FR, DEP_ON_STACK, TOP_OR_FR);                                      \
        DepFr_backchain_cp(DEP_FR) = NULL;                                                             \
        DepFr_leader_cp(DEP_FR) = NORM_CP(LEADER_CP);                                                  \
        DepFr_cons_cp(DEP_FR) = NORM_CP(CONS_CP);                                                      \
        DepFr_next(DEP_FR) = NEXT;                                                                     \
        DepFr_sg_fr(DEP_FR) = SG_FR;                                                                   \
        DepFr_last_answer(DEP_FR) = (continuation_ptr)CONSUMER_DEFAULT_LAST_ANSWER(SG_FR, DEP_FR);     \
        DepFr_type(DEP_FR) = NORMAL_DEP

#define new_table_entry(TAB_ENT, PRED_ENTRY, ATOM, ARITY)       \
        { ALLOC_TABLE_ENTRY(TAB_ENT);                           \
          TabEnt_init_lock_field(TAB_ENT);                      \
          TabEnt_pe(TAB_ENT) = PRED_ENTRY;                      \
          TabEnt_atom(TAB_ENT) = ATOM;                          \
          TabEnt_arity(TAB_ENT) = ARITY;                        \
          TabEnt_mode(TAB_ENT) = 0;                             \
          TabEnt_subgoal_trie(TAB_ENT) = NULL;                  \
          TabEnt_hash_chain(TAB_ENT) = NULL;                    \
          TabEnt_next(TAB_ENT) = GLOBAL_root_tab_ent;           \
          GLOBAL_root_tab_ent = TAB_ENT;                        \
        }

#define new_global_trie_node(NODE, ENTRY, CHILD, PARENT, NEXT)  \
        ALLOC_GLOBAL_TRIE_NODE(NODE);                           \
        TrNode_entry(NODE) = ENTRY;                             \
        TrNode_child(NODE) = CHILD;                             \
        TrNode_parent(NODE) = PARENT;                           \
        TrNode_next(NODE) = NEXT

#define new_root_answer_trie_node(NODE)                                 \
        ALLOC_ANSWER_TRIE_NODE(NODE);                                   \
        init_answer_trie_node(NODE, 0, 0, NULL, NULL, NULL, TRIE_ROOT_NT)
#define new_answer_trie_node(NODE, INSTR, ENTRY, CHILD, PARENT, NEXT)   \
        INCREMENT_GLOBAL_TRIE_REFS(ENTRY);                              \
        ALLOC_ANSWER_TRIE_NODE(NODE);                                   \
        init_answer_trie_node(NODE, INSTR, ENTRY, CHILD,                \
            PARENT, NEXT, INTERIOR_NT)
#define init_answer_trie_node(NODE, INSTR, ENTRY, CHILD, PARENT, NEXT, FLAGS)  \
        TrNode_instr(NODE) = INSTR;                                     \
        TrNode_entry(NODE) = ENTRY;                                     \
        TrNode_init_lock_field(NODE);                                   \
        TrNode_child(NODE) = CHILD;                                     \
        TrNode_parent(NODE) = PARENT;                                   \
        TrNode_next(NODE) = NEXT;                                       \
        TrNode_node_type(NODE) = FLAGS | ANSWER_TRIE_NT


#define MAX_NODES_PER_TRIE_LEVEL           8
#define MAX_NODES_PER_BUCKET               (MAX_NODES_PER_TRIE_LEVEL / 2)
#define BASE_HASH_BUCKETS                  64
#define HASH_ENTRY(ENTRY, SEED)   \
          (IsVarTerm(ENTRY) ? 0 : \
              (((unsigned long int) ENTRY) >> NumberOfLowTagBits) & (SEED))
#ifdef GLOBAL_TRIE
#define GLOBAL_TRIE_HASH_MARK              ((Term) MakeTableVarTerm(MAX_TABLE_VARS))
#define IS_GLOBAL_TRIE_HASH(NODE)          (TrNode_entry(NODE) == GLOBAL_TRIE_HASH_MARK)
#else
#endif /* GLOBAL_TRIE */
#define IS_SUBGOAL_TRIE_HASH(NODE)         TrNode_is_hash(NODE)
#define IS_ANSWER_TRIE_HASH(NODE)          TrNode_is_hash(NODE)


#define new_global_trie_hash(HASH, NUM_NODES)                       \
        ALLOC_GLOBAL_TRIE_HASH(HASH);                               \
        Hash_mark(HASH) = GLOBAL_TRIE_HASH_MARK;                    \
        Hash_num_buckets(HASH) = BASE_HASH_BUCKETS;                 \
        ALLOC_HASH_BUCKETS(Hash_buckets(HASH), BASE_HASH_BUCKETS);  \
	      Hash_num_nodes(HASH) = NUM_NODES


#define new_subgoal_trie_hash(HASH, NUM_NODES, TAB_ENT)             \
        ALLOC_SUBGOAL_TRIE_HASH(HASH);                              \
        init_subgoal_trie_hash(HASH, NUM_NODES, TAB_ENT, CALL_TRIE_NT)
        
#define init_subgoal_trie_hash(HASH, NUM_NODES, TAB_ENT, TYPE)      \
        TrNode_node_type(HASH) = HASH_HEADER_NT | TYPE;             \
        Hash_num_buckets(HASH) = BASE_HASH_BUCKETS;                 \
        ALLOC_HASH_BUCKETS(Hash_buckets(HASH), BASE_HASH_BUCKETS);  \
        Hash_num_nodes(HASH) = NUM_NODES;                           \
        SgHash_init_next_field(HASH, TAB_ENT)
        
#define new_sub_subgoal_trie_hash(HASH, NUM_NODES, TAB_ENT)         \
        { subg_hash_ptr sub_hash;                                   \
          ALLOC_SUB_SUBGOAL_TRIE_HASH(sub_hash);                    \
          HASH = (sg_hash_ptr)sub_hash;                             \
          init_subgoal_trie_hash(HASH, NUM_NODES, TAB_ENT,          \
                CALL_SUB_TRIE_NT);                                  \
          Hash_index_head(sub_hash) = NULL;                         \
        }
        
#define new_general_subgoal_trie_hash(HASH, NUM_NODES, TAB_ENT, FLAGS)  \
        if(IS_SUB_FLAG(FLAGS)) {                                        \
          new_sub_subgoal_trie_hash(HASH, NUM_NODES, TAB_ENT);          \
        } else {                                                        \
          new_subgoal_trie_hash(HASH, NUM_NODES, TAB_ENT)               \
        }
        
#define free_sub_subgoal_trie_hash(HASH)                            \
        { gen_index_ptr gen_index;                                  \
          gen_index = Hash_index_head((subg_hash_ptr)(HASH));       \
          while(gen_index) {                                        \
            FREE_GEN_INDEX_NODE(gen_index);                         \
            gen_index = GNIN_next(gen_index);                       \
          }                                                         \
          FREE_SUB_SUBGOAL_TRIE_HASH(HASH);                         \
        }
        
#define free_subgoal_trie_hash(HASH)                                \
        if(TrNode_is_sub_call(HASH)) {                              \
          free_sub_subgoal_trie_hash(HASH);                         \
        } else {                                                    \
          FREE_SUBGOAL_TRIE_HASH(HASH);                             \
        }

#define new_answer_trie_hash(HASH, NUM_NODES, SG_FR)                \
        ALLOC_ANSWER_TRIE_HASH(HASH);                               \
        TrNode_node_type(HASH) = HASH_HEADER_NT | ANSWER_TRIE_NT;   \
        Hash_num_buckets(HASH) = BASE_HASH_BUCKETS;                 \
        ALLOC_HASH_BUCKETS(Hash_buckets(HASH), BASE_HASH_BUCKETS);  \
        Hash_num_nodes(HASH) = NUM_NODES;                           \
        AnsHash_init_next_field(HASH, SG_FR)


#ifdef LIMIT_TABLING

#define insert_into_global_sg_fr_list(SG_FR)  {                              \
        SgFr_previous(SG_FR) = GLOBAL_last_sg_fr;                            \
        SgFr_next(SG_FR) = NULL;                                             \
        if (GLOBAL_first_sg_fr == NULL)                                      \
          GLOBAL_first_sg_fr = SG_FR;                                        \
        else                                                                 \
          SgFr_next(GLOBAL_last_sg_fr) = SG_FR;                              \
        GLOBAL_last_sg_fr = SG_FR;                                           \
    }
    
#define remove_from_global_sg_fr_list(SG_FR)  {                              \
        if (SgFr_previous(SG_FR)) {                                          \
          if ((SgFr_next(SgFr_previous(SG_FR)) = SgFr_next(SG_FR)) != NULL)  \
            SgFr_previous(SgFr_next(SG_FR)) = SgFr_previous(SG_FR);          \
          else                                                               \
            GLOBAL_last_sg_fr = SgFr_previous(SG_FR);                        \
        } else {                                                             \
          if ((GLOBAL_first_sg_fr = SgFr_next(SG_FR)) != NULL)               \
            SgFr_previous(SgFr_next(SG_FR)) = NULL;                          \
          else                                                               \
            GLOBAL_last_sg_fr = NULL;                                        \
	      }                                                                    \
        if (GLOBAL_check_sg_fr == SG_FR)                                     \
          GLOBAL_check_sg_fr = SgFr_previous(SG_FR);                         \
    }
    
#else
#define insert_into_global_sg_fr_list(SG_FR)
#define remove_from_global_sg_fr_list(SG_FR)
#endif /* LIMIT_TABLING */

/* Get a pointer to the consumer answer template by using B */
#define CONSUMER_NODE_ANSWER_TEMPLATE(CONSUMER_CP) ((CELL *) (CONS_CP(CONSUMER_CP) + 1))
#define CONSUMER_ANSWER_TEMPLATE(DEP_FR)  (DepFr_is_normal(DEP_FR) ? CONSUMER_NODE_ANSWER_TEMPLATE(B)  \
                                              : GENERATOR_ANSWER_TEMPLATE(DepFr_cons_cp(DEP_FR), DepFr_sg_fr(DEP_FR)))
#define DEPENDENCY_FRAME_ANSWER_TEMPLATE(DEP_FR)  ((CELL *)(CONS_CP(DepFr_cons_cp(DEP_FR)) + 1))
#define GENERATOR_ANSWER_TEMPLATE(GEN_CHOICEP, SG_FR) ((CELL *)(GEN_CP(GEN_CHOICEP) + 1) + SgFr_arity(SG_FR))

#define trail_unwind(TR0)                   \
  while(TR != TR0)  {                       \
    CELL *var = (CELL *)TrailTerm(--TR);    \
    RESET_VARIABLE(var);                    \
  }
  
/* --------------------------- **
**   Subsumption macros        **
** --------------------------- */

#include "tab.sub_macros.h"
        
#include "tab.types.h"

/* ------------------------- **
**      Inline funcions      **
** ------------------------- */

static inline
void adjust_freeze_registers(void) {
  B_FZ  = DepFr_cons_cp(LOCAL_top_dep_fr);
  H_FZ  = B_FZ->cp_h;
  TR_FZ = B_FZ->cp_tr;
  return;
}


static inline
void mark_as_completed(sg_fr_ptr sg_fr) {
  LOCK(SgFr_lock(sg_fr));

#ifdef FDEBUG
  printf("COMPLETED SUBGOAL: ");
  printSubgoalTriePath(stdout, SgFr_leaf(sg_fr), SgFr_tab_ent(sg_fr));
  dprintf("\n");
#endif
  
  SgFr_state(sg_fr) = complete;
  
  switch(SgFr_type(sg_fr)) {
    case VARIANT_PRODUCER_SFT:
      free_answer_trie_hash_chain((ans_hash_ptr)SgFr_hash_chain(sg_fr));
      SgFr_hash_chain(sg_fr) = NULL;
      break;
#ifdef TABLING_CALL_SUBSUMPTION
    case SUBSUMPTIVE_PRODUCER_SFT:
      if(TabEnt_is_exec(SgFr_tab_ent(sg_fr))) {
        free_tst_hash_index((tst_ans_hash_ptr)SgFr_hash_chain(sg_fr));
        /* answer list or blocks are not removed because of show_table */
      }
      break;
    case GROUND_PRODUCER_SFT:
      dprintf("One ground producer completed\n");
      mark_ground_producer_as_completed((grounded_sf_ptr)sg_fr);
      break;
#endif /* TABLING_CALL_SUBSUMPTION */
    default: break;
  }
  UNLOCK(SgFr_lock(sg_fr));
}

static inline
void unbind_variables(tr_fr_ptr unbind_tr, tr_fr_ptr end_tr) {
#ifdef TABLING_ERRORS
  if (unbind_tr < end_tr)
    TABLING_ERROR_MESSAGE("unbind_tr < end_tr (function unbind_variables)");
#endif /* TABLING_ERRORS */
  /* unbind loop */
  while (unbind_tr != end_tr) {
    CELL ref = (CELL) TrailTerm(--unbind_tr);
    /* check for global or local variables */
    if (IsVarTerm(ref)) {
      /* unbind variable */
      RESET_VARIABLE(ref);
    } else if (IsPairTerm(ref)) {
      ref = (CELL) RepPair(ref);
      if (IN_BETWEEN(Yap_TrailBase, ref, Yap_TrailTop)) {
        /* avoid frozen segments */
        unbind_tr = (tr_fr_ptr) ref;
#ifdef TABLING_ERRORS
        if (unbind_tr > (tr_fr_ptr) Yap_TrailTop)
          TABLING_ERROR_MESSAGE("unbind_tr > Yap_TrailTop (function unbind_variables)");
        if (unbind_tr < end_tr)
          TABLING_ERROR_MESSAGE("unbind_tr < end_tr (function unbind_variables)");
#endif /* TABLING_ERRORS */
      }
#ifdef MULTI_ASSIGNMENT_VARIABLES
    } else {
      CELL *aux_ptr = RepAppl(ref);
      --unbind_tr;
      Term aux_val = TrailVal(unbind_tr);
      *aux_ptr = aux_val;
#endif /* MULTI_ASSIGNMENT_VARIABLES */
    }
  }
  return;
}


static inline
void rebind_variables(tr_fr_ptr rebind_tr, tr_fr_ptr end_tr) {
#ifdef TABLING_ERRORS
  if (rebind_tr < end_tr)
    TABLING_ERROR_MESSAGE("rebind_tr < end_tr (function rebind_variables)");
#endif /* TABLING_ERRORS */
  /* rebind loop */
  Yap_NEW_MAHASH((ma_h_inner_struct *)H);
  while (rebind_tr != end_tr) {
    CELL ref = (CELL) TrailTerm(--rebind_tr);
    /* check for global or local variables */
    if (IsVarTerm(ref)) {
      /* rebind variable */
      *((CELL *)ref) = TrailVal(rebind_tr);
    } else if (IsPairTerm(ref)) {
      ref = (CELL) RepPair(ref);
      if (IN_BETWEEN(Yap_TrailBase, ref, Yap_TrailTop)) {
        /* avoid frozen segments */
  	rebind_tr = (tr_fr_ptr) ref;
#ifdef TABLING_ERRORS
        if (rebind_tr > (tr_fr_ptr) Yap_TrailTop)
          TABLING_ERROR_MESSAGE("rebind_tr > Yap_TrailTop (function rebind_variables)");
        if (rebind_tr < end_tr)
          TABLING_ERROR_MESSAGE("rebind_tr < end_tr (function rebind_variables)");
#endif /* TABLING_ERRORS */
      }
#ifdef MULTI_ASSIGNMENT_VARIABLES
    } else {
      CELL *cell_ptr = RepAppl(ref);
      if (!Yap_lookup_ma_var(cell_ptr)) {
	/* first time we found the variable, let's put the new value */
	*cell_ptr = TrailVal(rebind_tr);
      }
      --rebind_tr;
#endif /* MULTI_ASSIGNMENT_VARIABLES */
    }
  }
  return;
}



static inline
void restore_bindings(tr_fr_ptr unbind_tr, tr_fr_ptr rebind_tr) {
  CELL ref;
  tr_fr_ptr end_tr;

#ifdef TABLING_ERRORS
  if (unbind_tr < rebind_tr)
    TABLING_ERROR_MESSAGE("unbind_tr < rebind_tr (function restore_bindings)");
#endif /* TABLING_ERRORS */
  end_tr = rebind_tr;
  Yap_NEW_MAHASH((ma_h_inner_struct *)H);
  while (unbind_tr != end_tr) {
    /* unbind loop */
    while (unbind_tr > end_tr) {
      ref = (CELL) TrailTerm(--unbind_tr);
      if (IsVarTerm(ref)) {
        RESET_VARIABLE(ref);
      } else if (IsPairTerm(ref)) {
        ref = (CELL) RepPair(ref);
	if (IN_BETWEEN(Yap_TrailBase, ref, Yap_TrailTop)) {
	  /* avoid frozen segments */
          unbind_tr = (tr_fr_ptr) ref;
#ifdef TABLING_ERRORS
          if (unbind_tr > (tr_fr_ptr) Yap_TrailTop)
            TABLING_ERROR_MESSAGE("unbind_tr > Yap_TrailTop (function restore_bindings)");
#endif /* TABLING_ERRORS */
        }
#ifdef MULTI_ASSIGNMENT_VARIABLES
      }	else if (IsApplTerm(ref)) {
	CELL *pt = RepAppl(ref);

	/* AbsAppl means */
	/* multi-assignment variable */
	/* so that the upper cell is the old value */ 
	--unbind_tr;
	if (!Yap_lookup_ma_var(pt)) {
	  pt[0] = TrailVal(unbind_tr);
	}
#endif
      }
    }
    /* look for end */
    while (unbind_tr < end_tr) {
      ref = (CELL) TrailTerm(--end_tr);
      if (IsPairTerm(ref)) {
        ref = (CELL) RepPair(ref);
	if (IN_BETWEEN(Yap_TrailBase, ref, Yap_TrailTop)) {
	  /* avoid frozen segments */
  	  end_tr = (tr_fr_ptr) ref;
#ifdef TABLING_ERRORS
	  if (end_tr > (tr_fr_ptr) Yap_TrailTop)
            TABLING_ERROR_MESSAGE("end_tr > Yap_TrailTop (function restore_bindings)");
#endif /* TABLING_ERRORS */
        }
      }
    }
  }
  /* rebind loop */
  while (rebind_tr != end_tr) {
    ref = (CELL) TrailTerm(--rebind_tr);
    if (IsVarTerm(ref)) {
      *((CELL *)ref) = TrailVal(rebind_tr);
    } else if (IsPairTerm(ref)) {
      ref = (CELL) RepPair(ref);
      if (IN_BETWEEN(Yap_TrailBase, ref, Yap_TrailTop)) {
	/* avoid frozen segments */
        rebind_tr = (tr_fr_ptr) ref;
#ifdef TABLING_ERRORS
	if (rebind_tr > (tr_fr_ptr) Yap_TrailTop)
          TABLING_ERROR_MESSAGE("rebind_tr > Yap_TrailTop (function restore_bindings)");
        if (rebind_tr < end_tr)
TABLING_ERROR_MESSAGE("rebind_tr < end_tr (function restore_bindings)");
#endif /* TABLING_ERRORS */
      }
#ifdef MULTI_ASSIGNMENT_VARIABLES
    } else {
      CELL *cell_ptr = RepAppl(ref);
      /* first time we found the variable, let's put the new value */
      *cell_ptr = TrailVal(rebind_tr);
      --rebind_tr;
#endif /* MULTI_ASSIGNMENT_VARIABLES */
    }
  }
  return;
}

static inline void
free_answer_trie_node(ans_node_ptr node) {
  if(TrNode_is_answer(node)) {
    FREE_ANSWER_TRIE_NODE(node);
  } else {
    /* TST node */
    if(TrNode_is_long(node)) {
      FREE_LONG_TST_NODE(node);
    } else if(TrNode_is_float(node)) {
      FREE_FLOAT_TST_NODE(node);
    } else {
      FREE_TST_ANSWER_TRIE_NODE(node);
    }
  }
}

static inline void
free_subgoal_trie_node(sg_node_ptr node) {
  if(TrNode_is_sub_call(node)) {
    if(TrNode_is_long(node)) {
      FREE_LONG_SUB_SUBGOAL_TRIE_NODE(node);
    } else if(TrNode_is_float(node)) {
      FREE_FLOAT_SUB_SUBGOAL_TRIE_NODE(node);
    } else {
      FREE_SUB_SUBGOAL_TRIE_NODE(node);
    }
  } else {
    if(TrNode_is_long(node)) {
      FREE_LONG_SUBGOAL_TRIE_NODE(node);
    } else if(TrNode_is_float(node)) {
      FREE_FLOAT_SUBGOAL_TRIE_NODE(node);
    } else {
      FREE_SUBGOAL_TRIE_NODE(node);
    }
  }
}

static inline
void free_node_list(node_list_ptr list) {
  node_list_ptr next;

  while(list) {
    next = NodeList_next(list);
    FREE_NODE_LIST(list);
    list = next;
  }
}

#define new_general_subgoal_trie_node(NODE, DATA, CHILD, PARENT, NEXT, FLAGS) \
  if(IS_SUB_FLAG(FLAGS)) {                                                    \
    if(IS_FLOAT_FLAG(FLAGS)) {                                                \
      Float flt = *(Float *)(DATA);                                           \
      new_float_sub_subgoal_trie_node(NODE, flt, CHILD, PARENT, NEXT, FLAGS); \
    } else if(IS_LONG_INT_FLAG(FLAGS)) {                                      \
      Int li = *(Int *)(DATA);                                                \
      new_long_sub_subgoal_trie_node(NODE, li, CHILD, PARENT, NEXT, FLAGS);   \
    } else {                                                                  \
      Term t = (Term)(DATA);                                                  \
      new_sub_subgoal_trie_node(NODE, t, CHILD, PARENT, NEXT, FLAGS);         \
    }                                                                         \
   } else {                                                                   \
     if(IS_FLOAT_FLAG(FLAGS)) {                                               \
       Float flt = *(Float *)(DATA);                                          \
       new_float_subgoal_trie_node(NODE, flt, CHILD, PARENT, NEXT, FLAGS);    \
     } else if(IS_LONG_INT_FLAG(FLAGS)) {                                     \
       Int li = *(Int *)(DATA);                                               \
       new_long_subgoal_trie_node(NODE, li, CHILD, PARENT, NEXT, FLAGS);      \
     } else {                                                                 \
       Term t = (Term)(DATA);                                                 \
       new_subgoal_trie_node(NODE, t, CHILD, PARENT, NEXT, FLAGS);            \
     }                                                                        \
  }

static inline
void free_variant_subgoal_data(sg_fr_ptr sg_fr, int delete_all) {
  dprintf("Freeing variant subgoal data\n");
  free_answer_trie_hash_chain((ans_hash_ptr)SgFr_hash_chain(sg_fr));
  ans_node_ptr answer_trie = SgFr_answer_trie(sg_fr);
  if(TrNode_child(answer_trie))
    free_answer_trie_branch(TrNode_child(answer_trie), TRAVERSE_POSITION_FIRST);
  if(delete_all)
    FREE_ANSWER_TRIE_NODE(answer_trie);
  free_answer_continuation(SgFr_first_answer(sg_fr));
}

static void
abolish_incomplete_variant_subgoal(sg_fr_ptr sg_fr) {
  if (SgFr_has_no_answers(sg_fr)) {
    /* no answers --> ready */
    SgFr_state(sg_fr) = ready;
  } else if (SgFr_has_yes_answer(sg_fr)) {
    /* yes answer --> complete */
#ifndef TABLING_EARLY_COMPLETION
    /* with early completion, at this point the subgoal should be already completed */
    SgFr_state(sg_fr) = complete;
#endif /* TABLING_EARLY_COMPLETION */
    UNLOCK(SgFr_lock(sg_fr));
  } else {
    /* answers --> incomplete/ready */
#ifdef INCOMPLETE_TABLING
    SgFr_state(sg_fr) = incomplete;
#else
    free_variant_subgoal_data(sg_fr, FALSE);
    
    SgFr_first_answer(sg_fr) = NULL;
    SgFr_last_answer(sg_fr) = NULL;
    SgFr_state(sg_fr) = ready;
    SgFr_hash_chain(sg_fr) = NULL;
    TrNode_child(SgFr_answer_trie(sg_fr)) = NULL;
#endif /* INCOMPLETE_TABLING */
  }
}

static inline void
abolish_incomplete_producer_subgoal(sg_fr_ptr sg_fr) {
  switch(SgFr_type(sg_fr)) {
    case VARIANT_PRODUCER_SFT:
      abolish_incomplete_variant_subgoal(sg_fr);
      break;
#ifdef TABLING_CALL_SUBSUMPTION
    case SUBSUMPTIVE_PRODUCER_SFT:
      abolish_incomplete_subsumptive_producer_subgoal(sg_fr);
      break;
    case GROUND_PRODUCER_SFT:
      abolish_incomplete_ground_producer_subgoal(sg_fr);
      break;
#endif /* TABLING_CALL_SUBSUMPTION */
    default: break;
  }
}

static inline
void abolish_incomplete_subgoals(choiceptr prune_cp) {
#ifdef YAPOR
  if (EQUAL_OR_YOUNGER_CP(GetOrFr_node(LOCAL_top_susp_or_fr), prune_cp))
    pruning_over_tabling_data_structures();
#endif /* YAPOR */

  if (EQUAL_OR_YOUNGER_CP(DepFr_cons_cp(LOCAL_top_dep_fr), prune_cp)) {
#ifdef YAPOR
    if (PARALLEL_EXECUTION_MODE)
      pruning_over_tabling_data_structures();
#endif /* YAPOR */
    do {
      dep_fr_ptr dep_fr = LOCAL_top_dep_fr;
      LOCAL_top_dep_fr = DepFr_next(dep_fr);
      FREE_DEPENDENCY_FRAME(dep_fr);
    } while (EQUAL_OR_YOUNGER_CP(DepFr_cons_cp(LOCAL_top_dep_fr), prune_cp));
    adjust_freeze_registers();
  }

  while (LOCAL_top_sg_fr && EQUAL_OR_YOUNGER_CP(SgFr_choice_point(LOCAL_top_sg_fr), prune_cp)) {
    sg_fr_ptr sg_fr;
#ifdef YAPOR
    if (PARALLEL_EXECUTION_MODE)
      pruning_over_tabling_data_structures();
#endif /* YAPOR */
    sg_fr = LOCAL_top_sg_fr;
    LOCAL_top_sg_fr = SgFr_next(sg_fr);
    
    LOCK(SgFr_lock(sg_fr));
    abolish_incomplete_producer_subgoal(sg_fr);
    
    UNLOCK(SgFr_lock(sg_fr));
#ifdef LIMIT_TABLING
    insert_into_global_sg_fr_list(sg_fr);
#endif /* LIMIT_TABLING */
  }

#ifdef TABLING_CALL_SUBSUMPTION
  while (LOCAL_top_subcons_sg_fr && EQUAL_OR_YOUNGER_CP(SgFr_choice_point(LOCAL_top_subcons_sg_fr), prune_cp)) {
    subcons_fr_ptr sg_fr;
    
    sg_fr = LOCAL_top_subcons_sg_fr;
    LOCAL_top_subcons_sg_fr = SgFr_next(sg_fr);
    
    LOCK(SgFr_lock(sg_fr));
    abolish_incomplete_subsumptive_consumer_subgoal(sg_fr);
    UNLOCK(SgFr_lock(sg_fr));
  }
  
  while(LOCAL_top_groundcons_sg_fr && EQUAL_OR_YOUNGER_CP(SgFr_choice_point(LOCAL_top_groundcons_sg_fr), prune_cp)) {
    grounded_sf_ptr sg_fr;
    
    sg_fr = LOCAL_top_groundcons_sg_fr;
    LOCAL_top_groundcons_sg_fr = SgFr_next(sg_fr);
    
    LOCK(SgFr_lock(sg_fr));
    abolish_incomplete_ground_consumer_subgoal(sg_fr);
    dprintf("one incomplete grounded consumer\n");
    UNLOCK(SgFr_lock(sg_fr));
  }
#endif /* TABLING_CALL_SUBSUMPTION */

  return;
}

static inline
void free_subgoal_trie_hash_chain(sg_hash_ptr hash) {
  while (hash) {
    sg_node_ptr chain_node, *bucket, *last_bucket;
    sg_hash_ptr next_hash;

    bucket = Hash_buckets(hash);
    last_bucket = bucket + Hash_num_buckets(hash);
    while (! *bucket)
      bucket++;
    chain_node = *bucket;
    TrNode_child(TrNode_parent(chain_node)) = chain_node;
    while (++bucket != last_bucket) {
      if (*bucket) {
        while (TrNode_next(chain_node))
          chain_node = TrNode_next(chain_node);
        TrNode_next(chain_node) = *bucket;
        chain_node = *bucket;
      }
    }
    next_hash = Hash_next(hash);
    FREE_HASH_BUCKETS(Hash_buckets(hash));
    free_subgoal_trie_hash(hash);
    hash = next_hash;
  }
  return;
}


/*
 * free_answer_trie_hash_chain and free_tst_hash_chain
 * delete the hash tables chained in a subgoal frame
 * note that they are pretty similar, except
 * free_tst_hash_chain must deleted the TST indices
 */
static inline
void free_answer_trie_hash_chain(ans_hash_ptr hash) {
  while (hash) {
    ans_node_ptr chain_node, *bucket, *last_bucket;
    ans_hash_ptr next_hash;

    bucket = Hash_buckets(hash);
    last_bucket = bucket + Hash_num_buckets(hash);
    while (! *bucket)
      bucket++;
    chain_node = *bucket;
    TrNode_child(TrNode_parent(chain_node)) = chain_node;
    while (++bucket != last_bucket) {
      if (*bucket) {
        while (TrNode_next(chain_node))
          chain_node = TrNode_next(chain_node);
        TrNode_next(chain_node) = *bucket;
        chain_node = *bucket;
      }
    }
    dprintf("One hash deleted\n");
    next_hash = Hash_next(hash);
    FREE_HASH_BUCKETS(Hash_buckets(hash));
    FREE_ANSWER_TRIE_HASH(hash);
    hash = next_hash;
  }
  return;
}

/* from a dependency frame "dep_fr" compute if
 * new answers are available to consume
 */
static inline continuation_ptr
get_next_answer_continuation(dep_fr_ptr dep_fr) {
#ifdef TABLING_CALL_SUBSUMPTION
  sg_fr_ptr sg_fr = DepFr_sg_fr(dep_fr);
  
  switch(SgFr_type(sg_fr)) {
    case VARIANT_PRODUCER_SFT:
    case SUBSUMPTIVE_PRODUCER_SFT:
    case GROUND_PRODUCER_SFT:
      return continuation_next(DepFr_last_answer(dep_fr));
    case SUBSUMED_CONSUMER_SFT:
      {
        continuation_ptr last_cont = DepFr_last_answer(dep_fr);
        continuation_ptr next = continuation_next(last_cont);
        
        if(next)
          return next;
        else {
          /* check if new answers are available by:
           * (1) check if the timestamp from the subsuming
           *     subgoal frame is newer than the one we keep
           *     on the subsumed subgoal frame
           * (2) if (1) collect the new relevant answers
           *     from the TST and append them to the
           *     subsumed subgoal frame, finally
           *     return the continuation
           * (3) if (1) fails, no unconsumed answers
           *     are available and no continuation is returned
           */
          subcons_fr_ptr consumer_sg = (subcons_fr_ptr)sg_fr;
          if(build_next_subsumptive_consumer_return_list(consumer_sg))
            return continuation_next(last_cont);
          else
            return NULL;
        }
      }
      break;
    case GROUND_CONSUMER_SFT:
      {
        continuation_ptr last_cont = DepFr_last_answer(dep_fr);
        continuation_ptr next = continuation_next(last_cont);
        
        if(next)
          return next;
        
        grounded_sf_ptr consumer_sg = (grounded_sf_ptr)sg_fr;
        
        if(build_next_ground_consumer_return_list(consumer_sg))
          return continuation_next(last_cont);
        else
          return NULL;
      }
      break;
    default:
      /* NOT REACHABLE */
      return NULL;
  }
#else
  return continuation_next(DepFr_last_answer(dep_fr));
#endif /* TABLING_CALL_SUBSUMPTION */
}

/* Given a subgoal call result struct
 * tell if we must allocate a new generator
 */
static inline int
is_new_generator_call(sg_fr_ptr sg_fr) {
  switch(SgFr_type(sg_fr)) {
    case VARIANT_PRODUCER_SFT:
    case SUBSUMPTIVE_PRODUCER_SFT:
    case GROUND_PRODUCER_SFT:
      return SgFr_state(sg_fr) == ready;
#ifdef TABLING_CALL_SUBSUMPTION
    case SUBSUMED_CONSUMER_SFT:
      return FALSE;
#endif /* TABLING_CALL_SUBSUMPTION */
    default:
      /* NOT REACHABLE */
      return FALSE;
  }
}

/* Given a subgoal call result struct
 * tell if we must allocate a new consumer
 */
static inline int
is_new_consumer_call(sg_fr_ptr sg_fr) {
  switch(SgFr_type(sg_fr)) {
    case VARIANT_PRODUCER_SFT:
    case SUBSUMPTIVE_PRODUCER_SFT:
    case GROUND_PRODUCER_SFT:
      return SgFr_state(sg_fr) == evaluating;
#ifdef TABLING_CALL_SUBSUMPTION
    case SUBSUMED_CONSUMER_SFT:
      return SgFr_state(SgFr_producer((subcons_fr_ptr)sg_fr)) == evaluating;
    case GROUND_CONSUMER_SFT:
      return SgFr_state(SgFr_producer((grounded_sf_ptr)sg_fr)) == evaluating;
#endif /* TABLING_CALL_SUBSUMPTION */
    default:
      /* NOT REACHABLE */
      return FALSE;
  }
}


/*
static inline
choiceptr create_cp_and_freeze(void) {
  choiceptr freeze_cp;

  // initialize and store freeze choice point
  //  freeze_cp = (NORM_CP(YENV) - 1);
  freeze_cp = (NORM_CP(YENV) - 2);
  HBREG = H;
  store_yaam_reg_cpdepth(freeze_cp);
  freeze_cp->cp_tr = TR;
  freeze_cp->cp_ap = (yamop *)(TRUSTFAILCODE);
  freeze_cp->cp_h  = H;
  freeze_cp->cp_b  = B;
  freeze_cp->cp_env = ENV;
  freeze_cp->cp_cp = CPREG;
  // set_cut((CELL *)freeze_cp, B);
  B = freeze_cp;
  SET_BB(B);
  // adjust freeze registers
  B_FZ  = freeze_cp;
  H_FZ  = H;
  TR_FZ = TR;
  return freeze_cp;
}
*/


static inline
choiceptr freeze_current_cp(void) {
  choiceptr freeze_cp = B;

  B_FZ  = freeze_cp;
  H_FZ  = freeze_cp->cp_h;
  TR_FZ = freeze_cp->cp_tr;
  B = B->cp_b;
  HB = B->cp_h;
  return freeze_cp;
}


static inline
void resume_frozen_cp(choiceptr frozen_cp) {
  restore_bindings(TR, frozen_cp->cp_tr);
  B = frozen_cp;
  TR = TR_FZ;
  TRAIL_LINK(B->cp_tr);
  return;
}


static inline
void abolish_all_frozen_cps(void) {
  B_FZ  = (choiceptr) Yap_LocalBase;
  H_FZ  = (CELL *) Yap_GlobalBase;
  TR_FZ = (tr_fr_ptr) Yap_TrailBase;
  return;
}


#ifdef YAPOR
static inline
void pruning_over_tabling_data_structures(void) {
  Yap_Error(INTERNAL_ERROR, TermNil, "pruning over tabling data structures");
  return;
}


static inline
void collect_suspension_frames(or_fr_ptr or_fr) {  
  int depth;
  or_fr_ptr *susp_ptr;

#ifdef OPTYAP_ERRORS
  if (IS_UNLOCKED(or_fr))
    OPTYAP_ERROR_MESSAGE("or_fr unlocked (collect_suspension_frames)");
  if (OrFr_suspensions(or_fr) == NULL)
    OPTYAP_ERROR_MESSAGE("OrFr_suspensions(or_fr) == NULL (collect_suspension_frames)");
#endif /* OPTYAP_ERRORS */

  /* order collected suspension frames by depth */
  depth = OrFr_depth(or_fr);
  susp_ptr = & LOCAL_top_susp_or_fr;
  while (OrFr_depth(*susp_ptr) > depth)
    susp_ptr = & OrFr_nearest_suspnode(*susp_ptr);
  OrFr_nearest_suspnode(or_fr) = *susp_ptr;
  *susp_ptr = or_fr;
  return;
}


static inline
#ifdef TIMESTAMP_CHECK
susp_fr_ptr suspension_frame_to_resume(or_fr_ptr susp_or_fr, long timestamp) {
#else
susp_fr_ptr suspension_frame_to_resume(or_fr_ptr susp_or_fr) {
#endif /* TIMESTAMP_CHECK */
  choiceptr top_cp;
  susp_fr_ptr *susp_ptr, susp_fr;
  dep_fr_ptr dep_fr;

  top_cp = GetOrFr_node(susp_or_fr);
  susp_ptr = & OrFr_suspensions(susp_or_fr);
  susp_fr = *susp_ptr;
  while (susp_fr) {
    dep_fr = SuspFr_top_dep_fr(susp_fr);
    do {
      if (continuation_has_next(DepFr_last_answer(dep_fr))) {
        /* unconsumed answers in susp_fr */
        *susp_ptr = SuspFr_next(susp_fr);
        return susp_fr;
      }
#ifdef TIMESTAMP_CHECK
      DepFr_timestamp(dep_fr) = timestamp;
#endif /* TIMESTAMP_CHECK */
      dep_fr = DepFr_next(dep_fr);
#ifdef TIMESTAMP_CHECK
    } while (timestamp > DepFr_timestamp(dep_fr) && YOUNGER_CP(DepFr_cons_cp(dep_fr), top_cp));
#else
    } while (YOUNGER_CP(DepFr_cons_cp(dep_fr), top_cp));
#endif /* TIMESTAMP_CHECK */
    susp_ptr = & SuspFr_next(susp_fr);
    susp_fr = *susp_ptr;
  }
  /* no suspension frame with unconsumed answers */
  return NULL;
}
#endif /* YAPOR */



/* --------------------------------------------------- **
**      Cut Stuff: Managing table subgoal answers      **
** --------------------------------------------------- */

#ifdef TABLING_INNER_CUTS
static inline
void CUT_store_tg_answer(or_fr_ptr or_frame, ans_node_ptr ans_node, choiceptr gen_cp, int ltt) {
  tg_sol_fr_ptr tg_sol_fr, *solution_ptr, next, ltt_next;
  tg_ans_fr_ptr tg_ans_fr;

  solution_ptr = & OrFr_tg_solutions(or_frame);
  while (*solution_ptr && YOUNGER_CP(gen_cp, TgSolFr_gen_cp(*solution_ptr))) {
    solution_ptr = & TgSolFr_next(*solution_ptr);
  }
  if (*solution_ptr && gen_cp == TgSolFr_gen_cp(*solution_ptr)) {
    if (ltt >= TgSolFr_ltt(*solution_ptr)) {
      while (*solution_ptr && ltt > TgSolFr_ltt(*solution_ptr)) {
        solution_ptr = & TgSolFr_ltt_next(*solution_ptr);
      }
      if (*solution_ptr && ltt == TgSolFr_ltt(*solution_ptr)) {
        tg_ans_fr = TgSolFr_first(*solution_ptr);
        if (TgAnsFr_free_slot(tg_ans_fr) == TG_ANSWER_SLOTS) {
          ALLOC_TG_ANSWER_FRAME(tg_ans_fr);
          TgAnsFr_free_slot(tg_ans_fr) = 1;
          TgAnsFr_answer(tg_ans_fr, 0) = ans_node;
          TgAnsFr_next(tg_ans_fr) = TgSolFr_first(*solution_ptr);
          TgSolFr_first(*solution_ptr) = tg_ans_fr;
        } else {
          TgAnsFr_answer(tg_ans_fr, TgAnsFr_free_slot(tg_ans_fr)) = ans_node;
          TgAnsFr_free_slot(tg_ans_fr)++;
        }
        return;
      }
      ltt_next = *solution_ptr;
      next = NULL;
    } else {
      ltt_next = *solution_ptr;
      next = TgSolFr_next(*solution_ptr);
    }
  } else {
    ltt_next = NULL;
    next = *solution_ptr;
  }
  ALLOC_TG_ANSWER_FRAME(tg_ans_fr);
  TgAnsFr_free_slot(tg_ans_fr) = 1;
  TgAnsFr_answer(tg_ans_fr, 0) = ans_node;
  TgAnsFr_next(tg_ans_fr) = NULL;
  ALLOC_TG_SOLUTION_FRAME(tg_sol_fr);
  TgSolFr_gen_cp(tg_sol_fr) = gen_cp;
  TgSolFr_ltt(tg_sol_fr) = ltt;
  TgSolFr_first(tg_sol_fr) = tg_ans_fr;
  TgSolFr_last(tg_sol_fr) = tg_ans_fr;
  TgSolFr_ltt_next(tg_sol_fr) = ltt_next;
  TgSolFr_next(tg_sol_fr) = next;
  *solution_ptr = tg_sol_fr;
  return;
}


static inline
tg_sol_fr_ptr CUT_store_tg_answers(or_fr_ptr or_frame, tg_sol_fr_ptr new_solution, int ltt) {
  tg_sol_fr_ptr *old_solution_ptr, next_new_solution;
  choiceptr node, gen_cp;

  old_solution_ptr = & OrFr_tg_solutions(or_frame);
  node = GetOrFr_node(or_frame);
  while (new_solution && YOUNGER_CP(node, TgSolFr_gen_cp(new_solution))) {
    next_new_solution = TgSolFr_next(new_solution);
    gen_cp = TgSolFr_gen_cp(new_solution);
    while (*old_solution_ptr && YOUNGER_CP(gen_cp, TgSolFr_gen_cp(*old_solution_ptr))) {
      old_solution_ptr = & TgSolFr_next(*old_solution_ptr);
    }
    if (*old_solution_ptr && gen_cp == TgSolFr_gen_cp(*old_solution_ptr)) {
      if (ltt >= TgSolFr_ltt(*old_solution_ptr)) {
        tg_sol_fr_ptr *ltt_next_old_solution_ptr;
        ltt_next_old_solution_ptr = old_solution_ptr;
        while (*ltt_next_old_solution_ptr && ltt > TgSolFr_ltt(*ltt_next_old_solution_ptr)) {
          ltt_next_old_solution_ptr = & TgSolFr_ltt_next(*ltt_next_old_solution_ptr);
        }
        if (*ltt_next_old_solution_ptr && ltt == TgSolFr_ltt(*ltt_next_old_solution_ptr)) {
          TgAnsFr_next(TgSolFr_last(*ltt_next_old_solution_ptr)) = TgSolFr_first(new_solution);
          TgSolFr_last(*ltt_next_old_solution_ptr) = TgSolFr_last(new_solution);
          FREE_TG_SOLUTION_FRAME(new_solution);
        } else {
          TgSolFr_ltt(new_solution) = ltt;
          TgSolFr_ltt_next(new_solution) = *ltt_next_old_solution_ptr;
          TgSolFr_next(new_solution) = NULL;
          *ltt_next_old_solution_ptr = new_solution;
	}
      } else {
        TgSolFr_ltt(new_solution) = ltt;
        TgSolFr_ltt_next(new_solution) = *old_solution_ptr;
        TgSolFr_next(new_solution) = TgSolFr_next(*old_solution_ptr);
        *old_solution_ptr = new_solution;
      }
    } else {
      TgSolFr_ltt(new_solution) = ltt;
      TgSolFr_ltt_next(new_solution) = NULL;
      TgSolFr_next(new_solution) = *old_solution_ptr;
      *old_solution_ptr = new_solution;
    }
    old_solution_ptr = & TgSolFr_next(*old_solution_ptr);
    new_solution = next_new_solution;
  }
  return new_solution;
}


static inline
void CUT_validate_tg_answers(tg_sol_fr_ptr valid_solutions) {
  tg_ans_fr_ptr valid_answers, free_answer;
  tg_sol_fr_ptr ltt_valid_solutions, free_solution;
  continuation_ptr first_cont, last_cont, next_cont;
  sg_fr_ptr sg_fr;
  int slots;
  ans_node_ptr ans_node;
  
  first_cont = last_cont = next_cont = NULL;

  while (valid_solutions) {
    first_answer = last_answer = NULL;
#ifdef DETERMINISTIC_TABLING
    if (IS_DET_GEN_CP(TgSolFr_gen_cp(valid_solutions)))
      sg_fr = DET_GEN_CP(TgSolFr_gen_cp(valid_solutions))->cp_sg_fr;
    else
#endif /* DETERMINISTIC_TABLING */
      sg_fr = GEN_CP(TgSolFr_gen_cp(valid_solutions))->cp_sg_fr;
    ltt_valid_solutions = valid_solutions;
    valid_solutions = TgSolFr_next(valid_solutions);
    do {
      valid_answers = TgSolFr_first(ltt_valid_solutions);
      do {
        slots = TgAnsFr_free_slot(valid_answers);
        do {
          ans_node = TgAnsFr_answer(valid_answers, --slots);
#if defined(TABLE_LOCK_AT_ENTRY_LEVEL)
          LOCK(SgFr_lock(sg_fr));
#elif defined(TABLE_LOCK_AT_NODE_LEVEL)
          LOCK(TrNode_lock(ans_node));
#elif defined(TABLE_LOCK_AT_WRITE_LEVEL)
          LOCK_TABLE(ans_node);
#endif /* TABLE_LOCK_LEVEL */
          if (! IS_ANSWER_LEAF_NODE(ans_node)) {
            TAG_AS_ANSWER_LEAF_NODE(ans_node);
            
            push_new_answer_set(ans_node, first_cont, last_cont);
	        }
#if defined(TABLE_LOCK_AT_ENTRY_LEVEL)
          UNLOCK(SgFr_lock(sg_fr));
#elif defined(TABLE_LOCK_AT_NODE_LEVEL)
          UNLOCK(TrNode_lock(ans_node));
#elif defined(TABLE_LOCK_AT_WRITE_LEVEL)
          UNLOCK_TABLE(ans_node);
#endif /* TABLE_LOCK_LEVEL */
        } while (slots);
        free_answer = valid_answers;
        valid_answers = TgAnsFr_next(valid_answers);
        FREE_TG_ANSWER_FRAME(free_answer);
      } while (valid_answers);
      free_solution = ltt_valid_solutions;
      ltt_valid_solutions = TgSolFr_ltt_next(ltt_valid_solutions);
      FREE_TG_SOLUTION_FRAME(free_solution);
    } while (ltt_valid_solutions);
    
    if(first_cont) {
      LOCK(SgFr_lock(sg_fr));
      
      join_answers_subgoal_frame(sg_fr, first_cont, last_cont);
      
      UNLOCK(SgFr_lock(sg_fr));
    }
  }
  return;
}


static inline
void CUT_join_tg_solutions(tg_sol_fr_ptr *old_solution_ptr, tg_sol_fr_ptr new_solution) {
  tg_sol_fr_ptr next_old_solution, next_new_solution;
  choiceptr gen_cp;

  do {
    gen_cp = TgSolFr_gen_cp(new_solution);
    while (*old_solution_ptr && YOUNGER_CP(gen_cp, TgSolFr_gen_cp(*old_solution_ptr))) {
      old_solution_ptr = & TgSolFr_next(*old_solution_ptr);
    }
    if (*old_solution_ptr) {
      next_old_solution = *old_solution_ptr;
      *old_solution_ptr = new_solution;
      CUT_join_solution_frame_tg_answers(new_solution);
      if (gen_cp == TgSolFr_gen_cp(next_old_solution)) {
        tg_sol_fr_ptr free_solution;
        TgAnsFr_next(TgSolFr_last(new_solution)) = TgSolFr_first(next_old_solution);
        TgSolFr_last(new_solution) = TgSolFr_last(next_old_solution);
        free_solution = next_old_solution;
        next_old_solution = TgSolFr_next(next_old_solution);
        FREE_TG_SOLUTION_FRAME(free_solution);
        if (! next_old_solution) {
          if ((next_new_solution = TgSolFr_next(new_solution))) {
            CUT_join_solution_frames_tg_answers(next_new_solution);
	  }
          return;
	}
      }
      gen_cp = TgSolFr_gen_cp(next_old_solution);
      next_new_solution = TgSolFr_next(new_solution);
      while (next_new_solution && YOUNGER_CP(gen_cp, TgSolFr_gen_cp(next_new_solution))) {
        new_solution = next_new_solution;
        next_new_solution = TgSolFr_next(new_solution);
        CUT_join_solution_frame_tg_answers(new_solution);
      }
      old_solution_ptr = & TgSolFr_next(new_solution);
      TgSolFr_next(new_solution) = next_old_solution;
      new_solution = next_new_solution;
    } else {
      *old_solution_ptr = new_solution;
      CUT_join_solution_frames_tg_answers(new_solution);
      return;
    }
  } while (new_solution);
  return;
}


static inline 
void CUT_join_solution_frame_tg_answers(tg_sol_fr_ptr join_solution) {
  tg_sol_fr_ptr next_solution;

  while ((next_solution = TgSolFr_ltt_next(join_solution))) {
    TgAnsFr_next(TgSolFr_last(join_solution)) = TgSolFr_first(next_solution);
    TgSolFr_last(join_solution) = TgSolFr_last(next_solution);
    TgSolFr_ltt_next(join_solution) = TgSolFr_ltt_next(next_solution);
    FREE_TG_SOLUTION_FRAME(next_solution);
  }
  return;
}


static inline 
void CUT_join_solution_frames_tg_answers(tg_sol_fr_ptr join_solution) {
  do {
    CUT_join_solution_frame_tg_answers(join_solution);
    join_solution = TgSolFr_next(join_solution);
  } while (join_solution);
  return;
}


static inline 
void CUT_free_tg_solution_frame(tg_sol_fr_ptr solution) {
  tg_ans_fr_ptr current_answer, next_answer;

  current_answer = TgSolFr_first(solution);
  do {
    next_answer = TgAnsFr_next(current_answer);
    FREE_TG_ANSWER_FRAME(current_answer);
    current_answer = next_answer;
  } while (current_answer);
  FREE_TG_SOLUTION_FRAME(solution);
  return;
}


static inline 
void CUT_free_tg_solution_frames(tg_sol_fr_ptr current_solution) {
  tg_sol_fr_ptr ltt_solution, next_solution;

  while (current_solution) {
    ltt_solution = TgSolFr_ltt_next(current_solution);
    while (ltt_solution) {
      next_solution = TgSolFr_ltt_next(ltt_solution);
      CUT_free_tg_solution_frame(ltt_solution);
      ltt_solution = next_solution;
    }
    next_solution = TgSolFr_next(current_solution);
    CUT_free_tg_solution_frame(current_solution);
    current_solution = next_solution;
  }
  return;
}


static inline 
tg_sol_fr_ptr CUT_prune_tg_solution_frames(tg_sol_fr_ptr solutions, int ltt) {
  tg_sol_fr_ptr ltt_next_solution, return_solution;

  if (! solutions) return NULL;
  return_solution = CUT_prune_tg_solution_frames(TgSolFr_next(solutions), ltt);
  while (solutions && ltt > TgSolFr_ltt(solutions)) {
    ltt_next_solution = TgSolFr_ltt_next(solutions);
    CUT_free_tg_solution_frame(solutions);
    solutions = ltt_next_solution;
  }
  if (solutions) {
    TgSolFr_next(solutions) = return_solution;
    return solutions;
  } else {
    return return_solution;
  }
}
#endif /* TABLING_INNER_CUTS */
