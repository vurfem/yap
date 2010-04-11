/**********************************************************************
                                                               
                       The OPTYap Prolog system                
  OPTYap extends the Yap Prolog system to support or-parallel tabling
                                                               
  Copyright:   R. Rocha and NCC - University of Porto, Portugal
  File:        tab.tries.insts.i
  version:     $Id: tab.tries.insts.i,v 1.12 2007-04-26 14:11:08 ricroc Exp $   
                                                                     
**********************************************************************/

/* --------------------------------------------------------- **
**      Trie instructions: auxiliary stack organization      **
** --------------------------------------------------------- **
                 STANDARD_TRIE
              -------------------
              | ha = heap_arity | 
              -------------------  --
              |   heap ptr 1    |    |
              -------------------    |
              |       ...       |    -- heap_arity
              -------------------    |
              |   heap ptr ha   |    |
              -------------------  --
              | va = vars_arity |
              -------------------
              | sa = subs_arity |
              -------------------  --
              |   subs ptr sa   |    |
              -------------------    |
              |       ...       |    -- subs_arity 
              -------------------    |
              |   subs ptr 1    |    |
              -------------------  --
              |    var ptr va   |    |
              -------------------    |
              |       ...       |    -- vars_arity
              -------------------    |
              |    var ptr 1    |    |
              -------------------  -- 


                  GLOBAL_TRIE
              -------------------
              | va = vars_arity |
              -------------------  --
              |    var ptr va   |    |
              -------------------    |
              |       ...       |    -- vars_arity
              -------------------    |
              |    var ptr 1    |    |
              -------------------  -- 
              | sa = subs_arity |
              -------------------  --
              |   subs ptr sa   |    |
              -------------------    |
              |       ...       |    -- subs_arity 
              -------------------    |
              |   subs ptr 1    |    |
              -------------------  --
** --------------------------------------------------------- */



/* --------------------------------------------- **
**      Trie instructions: auxiliary macros      **
** --------------------------------------------- */

#ifdef GLOBAL_TRIE
#define copy_arity_stack()                                      \
        { int size = subs_arity + vars_arity + 2;               \
          YENV -= size;                                         \
          memcpy(YENV, aux_stack_ptr, size * sizeof(CELL *));   \
          aux_stack_ptr = YENV;                                 \
	}
#else
 
#define copy_arity_stack()                                      \
  {       int size = heap_arity + subs_arity + vars_arity + 3;  \
          YENV -= size;                                         \
          memcpy(YENV, aux_stack_ptr, size * sizeof(CELL *));   \
          aux_stack_ptr = YENV;                                 \
	}
#endif /* GLOBAL_TRIE */

#define align_stack_left() {                              \
      int i;                                              \
      for(i = 0; i < vars_arity; i++, aux_stack_ptr++) {  \
        *aux_stack_ptr = *(aux_stack_ptr + 1);            \
      }                                                   \
    }

/* if aux_stack_ptr is positioned on the heap arity cell, increment it by TOTAL */
#define inc_heap_arity(TOTAL) *aux_stack_ptr = heap_arity + (TOTAL)

#define next_trie_instruction(NODE) \
        next_node_instruction(TrNode_child(NODE))
        
#define next_node_instruction(NODE) {                           \
        PREG = (yamop *)(NODE);                                 \
        PREFETCH_OP(PREG);                                      \
        GONext();                                               \
      }

#define next_instruction(CONDITION, NODE)                       \
        if (CONDITION) {                                        \
          PREG = (yamop *) TrNode_child(NODE);                  \
        } else {                                                \
          /* procceed */                                        \
	        PREG = (yamop *) CPREG;                               \
	        YENV = ENV;                                           \
        }                                                       \
        PREFETCH_OP(PREG);                                      \
        GONext()



/* ---------------------------------------------------------------------------- **
** the 'store_trie_node', 'restore_trie_node' and 'pop_trie_node' macros do not **
** include the 'set_cut' macro because there are no cuts in trie instructions.  **
** ---------------------------------------------------------------------------- */
        
#define store_trie_node(AP)                           \
        { register choiceptr cp;                      \
          dprintf("store_trie_node\n");               \
          YENV = (CELL *) (NORM_CP(YENV) - 1);        \
          cp = NORM_CP(YENV);                         \
          HBREG = H;                                  \
          store_yaam_reg_cpdepth(cp);                 \
          cp->cp_tr = TR;                             \
          cp->cp_h  = H;                              \
          cp->cp_b  = B;                              \
          cp->cp_cp = CPREG;                          \
          cp->cp_ap = (yamop *) AP;                   \
          cp->cp_env= ENV;                            \
          B = cp;                                     \
          YAPOR_SET_LOAD(B);                          \
          SET_BB(B);                                  \
          TABLING_ERRORS_check_stack;                 \
	      }                                             \
        copy_arity_stack()

#define restore_trie_node(AP)                         \
        dprintf("restore_trie_node\n");               \
        H = HBREG = PROTECT_FROZEN_H(B);              \
        restore_yaam_reg_cpdepth(B);                  \
        CPREG = B->cp_cp;                             \
        ENV = B->cp_env;                              \
        YAPOR_update_alternative(PREG, (yamop *) AP)  \
        B->cp_ap = (yamop *) AP;                      \
        YENV = (CELL *) PROTECT_FROZEN_B(B);          \
        SET_BB(NORM_CP(YENV));                        \
        copy_arity_stack()
        
#define really_pop_trie_node()                        \
        dprintf("really_pop_trie_node\n");            \
        YENV = (CELL *) PROTECT_FROZEN_B((B + 1));    \
        H = PROTECT_FROZEN_H(B);                      \
        pop_yaam_reg_cpdepth(B);                      \
	      CPREG = B->cp_cp;                             \
        TABLING_close_alt(B);                         \
        ENV = B->cp_env;                              \
	      B = B->cp_b;                                  \
        HBREG = PROTECT_FROZEN_H(B);                  \
        SET_BB(PROTECT_FROZEN_B(B));                  \
        if ((choiceptr) YENV == B_FZ) {               \
          copy_arity_stack();                         \
        }

#ifdef YAPOR
#define pop_trie_node()                               \
        dprintf("pop_trie_node\n");                   \
        if (SCH_top_shared_cp(B)) {                   \
          restore_trie_node(NULL);                    \
        } else {                                      \
          really_pop_trie_node();                     \
        }
#else
#define pop_trie_node()  {          \
      dprintf("pop_trie_node\n");   \
      really_pop_trie_node()        \
    }
#endif /* YAPOR */



/* ------------------- **
**      trie_null      **
** ------------------- */

#define stack_trie_null_instr()                              \
        next_trie_instruction(node)

#ifdef TRIE_COMPACT_PAIRS
/* trie compiled code for term 'CompactPairInit' */
#define stack_trie_null_in_new_pair_instr()                  \
        if (heap_arity) {                                    \
          aux_stack_ptr++;                                   \
          Bind_Global((CELL *) *aux_stack_ptr, AbsPair(H));  \
          *aux_stack_ptr-- = (CELL) (H + 1);                 \
          *aux_stack_ptr-- = (CELL) H;                       \
          *aux_stack_ptr = heap_arity - 1 + 2;               \
          YENV = aux_stack_ptr;                              \
        } else {                                             \
          int i;                                             \
          *aux_stack_ptr-- = (CELL) (H + 1);                 \
          *aux_stack_ptr-- = (CELL) H;                       \
          *aux_stack_ptr = 2;                                \
          YENV = aux_stack_ptr;                              \
          aux_stack_ptr += 2 + 2;                            \
          *aux_stack_ptr = subs_arity - 1;                   \
          aux_stack_ptr += subs_arity;                       \
          Bind((CELL *) *aux_stack_ptr, AbsPair(H));         \
          for (i = 0; i < vars_arity; i++) {                 \
            *aux_stack_ptr = *(aux_stack_ptr + 1);           \
            aux_stack_ptr++;                                 \
          }                                                  \
        }                                                    \
        H += 2;                                              \
        next_trie_instruction(node)
#endif /* TRIE_COMPACT_PAIRS */



/* ------------------ **
**      trie_var      **
** ------------------ */

#define stack_trie_var_instr()                                   \
        if (heap_arity) {                                        \
          CELL term;                                             \
          int i;                                                 \
          *aux_stack_ptr = heap_arity - 1;                       \
          term = Deref(*++aux_stack_ptr);                        \
          for (i = 0; i < heap_arity - 1; i++) {                 \
            *aux_stack_ptr = *(aux_stack_ptr + 1);               \
            aux_stack_ptr++;                                     \
          }                                                      \
          *aux_stack_ptr++ = vars_arity + 1;                     \
          *aux_stack_ptr++ = subs_arity;                         \
          for (i = 0; i < subs_arity; i++) {                     \
            *aux_stack_ptr = *(aux_stack_ptr + 1);               \
            aux_stack_ptr++;                                     \
          }                                                      \
          *aux_stack_ptr = term;                                 \
          next_instruction(heap_arity - 1 || subs_arity, node);  \
        } else {                                                 \
          *++aux_stack_ptr = vars_arity + 1;                     \
          *++aux_stack_ptr = subs_arity - 1;                     \
          /* binding is done automatically */                    \
          next_instruction(subs_arity - 1, node);                \
        }

#ifdef TRIE_COMPACT_PAIRS
#define stack_trie_var_in_new_pair_instr()                       \
        if (heap_arity) {                                        \
          int i;                                                 \
          *aux_stack_ptr-- = (CELL) (H + 1);                     \
          *aux_stack_ptr = heap_arity - 1 + 1;                   \
          YENV = aux_stack_ptr;                                  \
          aux_stack_ptr += 2;                                    \
          Bind_Global((CELL *) *aux_stack_ptr, AbsPair(H));      \
          for (i = 0; i < heap_arity - 1; i++) {                 \
            *aux_stack_ptr = *(aux_stack_ptr + 1);               \
            aux_stack_ptr++;                                     \
          }                                                      \
          *aux_stack_ptr++ = vars_arity + 1;                     \
          *aux_stack_ptr++ = subs_arity;                         \
          for (i = 0; i < subs_arity; i++) {                     \
            *aux_stack_ptr = *(aux_stack_ptr + 1);               \
            aux_stack_ptr++;                                     \
          }                                                      \
          *aux_stack_ptr = (CELL) H;                             \
        } else {                                                 \
          *aux_stack_ptr-- = (CELL) (H + 1);                     \
          *aux_stack_ptr = 1;                                    \
          YENV = aux_stack_ptr;                                  \
          aux_stack_ptr += 2;                                    \
          *aux_stack_ptr++ = vars_arity + 1;                     \
          *aux_stack_ptr = subs_arity - 1;                       \
          aux_stack_ptr += subs_arity;                           \
          Bind((CELL *) *aux_stack_ptr, AbsPair(H));             \
          *aux_stack_ptr = (CELL) H;                             \
        }                                                        \
        RESET_VARIABLE((CELL) H);                                \
        H += 2;                                                  \
        next_trie_instruction(node)
#endif /* TRIE_COMPACT_PAIRS */



/* ------------------ **
**      trie_val      **
** ------------------ */

#define unify_seen_var_var()                    \
  if (aux_sub > aux_var) {                      \
    if ((CELL *) aux_sub <= H) {                \
      Bind_Global((CELL *) aux_sub, aux_var);   \
    } else if ((CELL *) aux_var <= H) {         \
      Bind_Local((CELL *) aux_sub, aux_var);    \
    } else {                                    \
      Bind_Local((CELL *) aux_var, aux_sub);    \
      *vars_ptr = aux_sub;                      \
    }                                           \
  } else {                                      \
    if ((CELL *) aux_var <= H) {                \
      Bind_Global((CELL *) aux_var, aux_sub);   \
      *vars_ptr = aux_sub;                      \
    } else if ((CELL *) aux_sub <= H) {         \
      Bind_Local((CELL *) aux_var, aux_sub);    \
      *vars_ptr = aux_sub;                      \
    } else {                                    \
      Bind_Local((CELL *) aux_sub, aux_var);    \
    }                                           \
  }

#ifdef TABLING_CALL_SUBSUMPTION
#define unify_seen_var()                                    \
  switch(cell_tag(aux_sub)) {                               \
      case TAG_REF:                                         \
          switch(cell_tag(aux_var)) {                       \
            case TAG_REF:                                   \
              unify_seen_var_var();                         \
              break;                                        \
            default:                                        \
              Bind_Global((CELL *)aux_sub, aux_var);        \
              break;                                        \
          }                                                 \
        break;                                              \
      default:                                              \
        switch(cell_tag(aux_var)) {                         \
          case TAG_REF:                                     \
            if((CELL *) aux_var <= H) {                     \
              Bind_Global((CELL *) aux_var, aux_sub);       \
              *vars_ptr = aux_sub;                          \
            } else {                                        \
              Bind_Local((CELL *) aux_var, aux_sub);        \
              *vars_ptr = aux_sub;                          \
            }                                               \
            break;                                          \
          default:                                          \
            if(!Yap_unify(aux_var, aux_sub))                \
              goto fail;                                    \
            break;                                          \
        }                                                   \
  }
#else
#define unify_seen_var unify_seen_var_var
#endif /* TABLING_CALL_SUBSUMPTION */

#define stack_trie_val_instr()                                                              \
        if (heap_arity) {                                                                   \
          CELL aux_sub, aux_var, *vars_ptr;				                                          \
          YENV = ++aux_stack_ptr;                                                           \
          vars_ptr = aux_stack_ptr + heap_arity + 1 + subs_arity + vars_arity - var_index;  \
          aux_sub = Deref(*aux_stack_ptr); /* substitution var */                           \
          aux_var = Deref(*vars_ptr);                                                       \
          unify_seen_var();                                                                 \
          inc_heap_arity(-1);                                                               \
          next_instruction(heap_arity - 1 || subs_arity, node);                             \
        } else {                                                                            \
          CELL aux_sub, aux_var, *vars_ptr;                                                 \
          aux_stack_ptr += 2;                                                               \
          *aux_stack_ptr = subs_arity - 1;                                                  \
          aux_stack_ptr += subs_arity;                                                      \
          vars_ptr = aux_stack_ptr + vars_arity - var_index; /* pointer to trie var */      \
          aux_sub = Deref(*aux_stack_ptr);  /* substitution var */                          \
          aux_var = Deref(*vars_ptr);  /* trie var */                                       \
          unify_seen_var();                                                                 \
          align_stack_left();                                                               \
          next_instruction(subs_arity - 1, node);                                           \
        }

#ifdef TRIE_COMPACT_PAIRS      
#define stack_trie_val_in_new_pair_instr()                                                  \
        if (heap_arity) {                                                                   \
          CELL aux_sub, aux_var, *vars_ptr;	      	               		                      \
          aux_stack_ptr++;				                                                          \
          Bind_Global((CELL *) *aux_stack_ptr, AbsPair(H));                                 \
          *aux_stack_ptr = (CELL) (H + 1);                                                  \
          aux_sub = (CELL) H;                                                               \
          vars_ptr = aux_stack_ptr + heap_arity + 1 + subs_arity + vars_arity - var_index;  \
          aux_var = *vars_ptr;                                                              \
          if (aux_sub > aux_var) {                                                          \
            Bind_Global((CELL *) aux_sub, aux_var);                                         \
          } else {                                                                          \
            RESET_VARIABLE(aux_sub);                                                        \
  	        Bind_Local((CELL *) aux_var, aux_sub);                                          \
            *vars_ptr = aux_sub;                                                            \
          }                                                                                 \
        } else {                                                                            \
          CELL aux_sub, aux_var, *vars_ptr;                                                 \
          int i;                                                                            \
          *aux_stack_ptr-- = (CELL) (H + 1);                                                \
          *aux_stack_ptr = 1;                                                               \
          YENV = aux_stack_ptr;                                                             \
          aux_stack_ptr += 1 + 2;                                                           \
          aux_sub = (CELL) H;                                                               \
          vars_ptr = aux_stack_ptr + subs_arity + vars_arity - var_index;                   \
          aux_var = *vars_ptr;                                                              \
          if (aux_sub > aux_var) {                                                          \
            Bind_Global((CELL *) aux_sub, aux_var);                                         \
          } else {                                                                          \
            RESET_VARIABLE(aux_sub);                                                        \
	          Bind_Local((CELL *) aux_var, aux_sub);                                          \
            *vars_ptr = aux_sub;                                                            \
          }                                                                                 \
          *aux_stack_ptr = subs_arity - 1;                                                  \
          aux_stack_ptr += subs_arity;                                                      \
          Bind((CELL *) *aux_stack_ptr, AbsPair(H));                                        \
          for (i = 0; i < vars_arity; i++) {                                                \
            *aux_stack_ptr = *(aux_stack_ptr + 1);                                          \
            aux_stack_ptr++;                                                                \
          }                                                                                 \
        }                                                                                   \
        H += 2;                                                                             \
        next_trie_instruction(node)
#endif /* TRIE_COMPACT_PAIRS */


#ifdef TABLING_CALL_SUBSUMPTION

/* ------------------- **
**    trie_long_int    **
** ------------------- */

#define unify_long_int(BIND_FUN)                                                      \
  CELL term = Deref(*aux_stack_ptr);                                                  \
  switch(cell_tag(term)) {                                                            \
    case TAG_REF:                                                                     \
      BIND_FUN((CELL *)term, MkLongIntTerm(TSTN_long_int((long_tst_node_ptr)node)));  \
      break;                                                                          \
    case TAG_LONG_INT:                                                                \
      if(LongIntOfTerm(term) != TSTN_long_int((long_tst_node_ptr)node))               \
        goto fail;                                                                    \
      break;                                                                          \
    default:                                                                          \
      goto fail;                                                                      \
  }

#define stack_trie_long_instr()                                                       \
  if(heap_arity) {                                                                    \
    YENV = ++aux_stack_ptr;                                                           \
    unify_long_int(Bind_Global);                                                      \
    inc_heap_arity(-1);                                                               \
    next_instruction(heap_arity - 1 || subs_arity, node);                             \
  } else {                                                                            \
    aux_stack_ptr += 2;                                                               \
    *aux_stack_ptr = subs_arity - 1;                                                  \
    aux_stack_ptr += subs_arity;                                                      \
    unify_long_int(Bind);                                                             \
    align_stack_left();                                                               \
    next_instruction(subs_arity - 1, node);                                           \
  }
  
/* ------------------- **
**   trie_float_val    **
** ------------------- */
  
#define unify_float(BIND_FUN)                                                         \
  CELL term = Deref(*aux_stack_ptr);                                                  \
  switch(cell_tag(term)) {                                                            \
    case TAG_REF:                                                                     \
      BIND_FUN((CELL *)term, MkFloatTerm(TSTN_float((float_tst_node_ptr)node)));      \
      break;                                                                          \
    case TAG_FLOAT:                                                                   \
      if(FloatOfTerm(term) != TSTN_float((float_tst_node_ptr)node))                   \
        goto fail;                                                                    \
      break;                                                                          \
    default:                                                                          \
      goto fail;                                                                      \
  }
  
#define stack_trie_float_instr()                                                      \
  if(heap_arity) {                                                                    \
    YENV = ++aux_stack_ptr;                                                           \
    unify_float(Bind_Global);                                                         \
    inc_heap_arity(-1);                                                               \
    next_instruction(heap_arity - 1 || subs_arity, node);                             \
  } else {                                                                            \
    aux_stack_ptr += 2;                                                               \
    *aux_stack_ptr = subs_arity - 1;                                                  \
    aux_stack_ptr += subs_arity;                                                      \
    unify_float(Bind);                                                                \
    align_stack_left();                                                               \
    next_instruction(subs_arity - 1, node);                                           \
  }
  
#endif /* TABLING_CALL_SUBSUMPTION */

/* ------------------- **
**      trie_atom      **
** ------------------- */

#ifdef TABLING_CALL_SUBSUMPTION
#define unify_atom(BIND_FUN)                                  \
  CELL term = Deref(*aux_stack_ptr);                          \
  if(IsVarTerm(term)) {                                       \
    BIND_FUN((CELL *)term, TrNode_entry(node));               \
  } else {                                                    \
    if(term != TrNode_entry(node)) {                          \
      goto fail;                                              \
    }                                                         \
  }
#else
#define unify_atom(BIND_FUN) BIND_FUN((CELL *)*aux_stack_ptr, TrNode_entry(node))
#endif /* TABLING_CALL_SUBSUMPTION */

#define stack_trie_atom_instr()                                      \
        dprintf("stack_trie_atom_instr\n");                          \
        if (heap_arity) {                                            \
          YENV = ++aux_stack_ptr;                                    \
          unify_atom(Bind_Global);                                   \
          inc_heap_arity(-1);                                        \
          next_instruction(heap_arity - 1 || subs_arity, node);      \
        } else {                                                     \
          aux_stack_ptr += 2;                                        \
          *aux_stack_ptr = subs_arity - 1;                           \
          aux_stack_ptr += subs_arity;                               \
          unify_atom(Bind);                                          \
          align_stack_left();                                        \
          next_instruction(subs_arity - 1, node);                    \
        }

#ifdef TRIE_COMPACT_PAIRS
#define stack_trie_atom_in_new_pair_instr()                          \
        if (heap_arity) {                                            \
          aux_stack_ptr++;		                             \
          Bind_Global((CELL *) *aux_stack_ptr, AbsPair(H));          \
          *aux_stack_ptr = (CELL) (H + 1);                           \
        } else {                                                     \
          int i;                                                     \
          *aux_stack_ptr-- = (CELL) (H + 1);                         \
          *aux_stack_ptr = 1;                                        \
          YENV = aux_stack_ptr;                                      \
          aux_stack_ptr += 1 + 2;                                    \
          *aux_stack_ptr = subs_arity - 1;                           \
          aux_stack_ptr += subs_arity;                               \
          Bind((CELL *) *aux_stack_ptr, AbsPair(H));                 \
          for (i = 0; i < vars_arity; i++) {                         \
            *aux_stack_ptr = *(aux_stack_ptr + 1);                   \
            aux_stack_ptr++;                                         \
          }                                                          \
        }                                                            \
        Bind_Global(H, TrNode_entry(node));                          \
        H += 2;                                                      \
        next_trie_instruction(node)
#endif /* TRIE_COMPACT_PAIRS */



/* ------------------- **
**      trie_pair      **
** ------------------- */

#define push_list_args(TERM) {              \
  *aux_stack_ptr-- = *(RepPair(TERM) + 1);  \
  *aux_stack_ptr-- = *(RepPair(TERM) + 0);  \
}

#define push_new_list() {               \
  *aux_stack_ptr-- = (CELL) (H + 1);    \
  *aux_stack_ptr-- = (CELL) H;          \
}

#define mark_heap_list() {  \
    RESET_VARIABLE(H);      \
    RESET_VARIABLE(H+1);    \
    H += 2;                 \
  }

#ifdef TRIE_COMPACT_PAIRS
/* trie compiled code for term 'CompactPairEndList' */
#define stack_trie_pair_instr()		                           \
        if (heap_arity) {                                    \
          aux_stack_ptr++;                                   \
          Bind_Global((CELL *) *aux_stack_ptr, AbsPair(H));  \
          *aux_stack_ptr = (CELL) H;                         \
	      } else {                                             \
          int i;                                             \
          *aux_stack_ptr-- = (CELL) H;                       \
          *aux_stack_ptr = 1;                                \
          YENV = aux_stack_ptr;                              \
          aux_stack_ptr += 1 + 2;                            \
          *aux_stack_ptr = subs_arity - 1;                   \
          aux_stack_ptr += subs_arity;                       \
          Bind((CELL *) *aux_stack_ptr, AbsPair(H));         \
          for (i = 0; i < vars_arity; i++) {                 \
            *aux_stack_ptr = *(aux_stack_ptr + 1);           \
            aux_stack_ptr++;                                 \
          }                                                  \
	      }                                                    \
        Bind_Global(H + 1, TermNil);                         \
        H += 2;                                              \
        next_trie_instruction(node)
#else /* !TRIE_COMPACT_PAIRS */

#define unify_heap_var_pair()                             \
        Bind_Global((CELL *) *aux_stack_ptr, AbsPair(H)); \
        push_new_list();                                  \
        inc_heap_arity(1);                                \
        YENV = aux_stack_ptr;                             \
        mark_heap_list()
        
#ifdef TABLING_CALL_SUBSUMPTION
#define unify_heap_pair()                                       \
        switch(cell_tag(term)) {                                \
          case TAG_LIST: {                                      \
              push_list_args(term);                             \
              inc_heap_arity(1);                                \
              YENV = aux_stack_ptr;                             \
            }                                                   \
            break;                                              \
          case TAG_REF: {                                       \
              unify_heap_var_pair();                            \
            }                                                   \
            break;                                              \
          default:                                              \
            goto fail;                                          \
        }
#else
#define unify_heap_pair unify_heap_var_pair
#endif

#define unify_subs_var_pair()                           \
        push_new_list();                                \
        inc_heap_arity(2);                              \
        YENV = aux_stack_ptr;                           \
        /* jump to subs */                              \
        aux_stack_ptr += 2 + 2;                         \
        /* change subs arity */                         \
        *aux_stack_ptr = subs_arity - 1;                \
        aux_stack_ptr += subs_arity;                    \
        Bind((CELL *) *aux_stack_ptr, AbsPair(H));      \
        align_stack_left();                             \
        mark_heap_list()

#ifdef TABLING_CALL_SUBSUMPTION
#define unify_subs_pair()                                     \
        switch(cell_tag(term))  {                             \
          case TAG_LIST:  {                                   \
              push_list_args(term);                           \
              inc_heap_arity(2);                              \
              YENV = aux_stack_ptr;                           \
              /* jump to subs */                              \
              aux_stack_ptr += 2 + 2;                         \
              /* update subs arity */                         \
              *aux_stack_ptr = subs_arity - 1;                \
              aux_stack_ptr += subs_arity;                    \
              align_stack_left();                             \
            }                                                 \
            break;                                            \
          case TAG_REF: {                                     \
              unify_subs_var_pair();                          \
            }                                                 \
            break;                                            \
          default:                                            \
              goto fail;                                      \
        }
#else
#define unify_subs_pair unify_subs_var_pair
#endif /* TABLING_CALL_SUBSUMPTION */
        
#define stack_trie_pair_instr()                                 \
        if (heap_arity) {                                       \
          aux_stack_ptr++;                                      \
          Term term = Deref(*aux_stack_ptr);                    \
          unify_heap_pair();                                    \
        } else {                                                \
          CELL term = Deref(*(aux_stack_ptr + 2 + subs_arity)); \
          unify_subs_pair();                                    \
        }                                                       \
        next_trie_instruction(node)
        
#endif /* TRIE_COMPACT_PAIRS */

/* --------------------- **
**      trie_struct      **
** --------------------- */

/* given a functor term this push on the stack
   starting from aux_stack_ptr (from high to low)
   the functor arguments of TERM */
#define push_functor_args(TERM)  {                  \
    int i;                                          \
    for(i = 0; i < func_arity; ++i) {               \
      *aux_stack_ptr-- =                            \
          (CELL)*(RepAppl(TERM) + func_arity - i);  \
    }                                               \
  }
  
#define push_new_functor()  {                         \
    int i;                                            \
    for (i = 0; i < func_arity; i++) {                \
      *aux_stack_ptr-- = (CELL) (H + func_arity - i); \
    }                                                 \
  }

/* tag a functor on the heap */
#define mark_heap_functor() {       \
  *H = (CELL)func;                  \
  int i;                            \
  for(i = 0; i < func_arity; ++i)   \
    RESET_VARIABLE(H + 1 + i);      \
  H += 1 + func_arity;              \
}

#define unify_heap_struct_var()                       \
    /* bind this variable to a new functor            \
      that is built using the arguments on the trie   \
     */                                               \
    Bind_Global((CELL *) term, AbsAppl(H));           \
    push_new_functor();                               \
    YENV = aux_stack_ptr;                             \
    inc_heap_arity(func_arity - 1);                   \
    mark_heap_functor()
    
#ifdef TABLING_CALL_SUBSUMPTION
#define unify_heap_struct()                                 \
    switch(cell_tag(term))  {                               \
      case TAG_STRUCT:  {                                   \
          Functor func2 = FunctorOfTerm(term);              \
          if(func != func2) {                               \
            goto fail;                                      \
          }                                                 \
          push_functor_args(term);                          \
          YENV = aux_stack_ptr;                             \
          inc_heap_arity(func_arity - 1);                   \
        }                                                   \
        break;                                              \
      case TAG_REF: {                                       \
          unify_heap_struct_var();                          \
        }                                                   \
        break;                                              \
      default:                                              \
        goto fail;                                          \
    }
#else
#define unify_heap_struct unify_heap_struct_var
#endif /* TABLING_CALL_SUBSUMPTION */

#define unify_subs_struct_var()                 \
    push_new_functor();                                 \
    inc_heap_arity(func_arity);                         \
    YENV = aux_stack_ptr;                               \
    /* jump to subs */                                  \
    aux_stack_ptr += func_arity + 2;                    \
    /* new subs arity */                                \
    *aux_stack_ptr = subs_arity - 1;                    \
    aux_stack_ptr += subs_arity;                        \
    Bind((CELL *) *aux_stack_ptr, AbsAppl(H));          \
    align_stack_left();                                 \
    mark_heap_functor()

#ifdef TABLING_CALL_SUBSUMPTION
#define unify_subs_struct()                                   \
    switch(cell_tag(term))  {                                 \
      case TAG_STRUCT: {                                      \
          Functor func2 = FunctorOfTerm(term);                \
          if(func != func2) {                                 \
            goto fail;                                        \
          }                                                   \
          /* push already built functor terms on the stack */ \
          push_functor_args(term);                            \
          YENV = aux_stack_ptr;                               \
          inc_heap_arity(func_arity);                         \
          /* jump to subs*/                                   \
          aux_stack_ptr += func_arity + 2;                    \
          /* new subs arity */                                \
          *aux_stack_ptr = subs_arity - 1;                    \
          aux_stack_ptr += subs_arity;                        \
          align_stack_left();                                 \
        }                                                     \
        break;                                                \
      case TAG_REF:     {                                     \
          unify_subs_struct_var();                            \
        }                                                     \
        break;                                                \
      default:                                                \
        goto fail;                                            \
    }
#else
#define unify_subs_struct unify_subs_struct_var
#endif /* TABLING_CALL_SUBSUMPTION */

#define stack_trie_struct_instr()                                 \
        dprintf("stack_trie_struct_instr\n");                     \
        if (heap_arity) {                                         \
          aux_stack_ptr++;                                        \
          CELL term = Deref(*aux_stack_ptr);                      \
          unify_heap_struct();                                    \
        } else {                                                  \
          CELL term = Deref(*(aux_stack_ptr + 2 + subs_arity));   \
          unify_subs_struct();                                    \
        }                                                         \
        next_trie_instruction(node)

#ifdef TRIE_COMPACT_PAIRS
#define stack_trie_struct_in_new_pair_instr()	                 \
        if (heap_arity) {                                        \
          int i;                                                 \
          aux_stack_ptr++;		                         \
          Bind_Global((CELL *) *aux_stack_ptr, AbsPair(H));      \
          *aux_stack_ptr-- = (CELL) (H + 1);                     \
          for (i = 0; i < func_arity; i++)                       \
            *aux_stack_ptr-- = (CELL) (H + 2 + func_arity - i);  \
          *aux_stack_ptr = heap_arity - 1 + 1 + func_arity;      \
          YENV = aux_stack_ptr;                                  \
        } else {                                                 \
          int i;                                                 \
          *aux_stack_ptr-- = (CELL) (H + 1);                     \
          for (i = 0; i < func_arity; i++)                       \
            *aux_stack_ptr-- = (CELL) (H + 2 + func_arity - i);  \
          *aux_stack_ptr = 1 + func_arity;                       \
          YENV = aux_stack_ptr;                                  \
          aux_stack_ptr += 1 + func_arity + 2;                   \
          *aux_stack_ptr = subs_arity - 1;                       \
          aux_stack_ptr += subs_arity;                           \
          Bind((CELL *) *aux_stack_ptr, AbsPair(H));             \
          for (i = 0; i < vars_arity; i++) {                     \
            *aux_stack_ptr = *(aux_stack_ptr + 1);               \
            aux_stack_ptr++;                                     \
          }                                                      \
        }                                                        \
        Bind_Global(H, AbsAppl(H + 2));                          \
        H += 2;                                                  \
        *H = (CELL) func;                                        \
        H += 1 + func_arity;                                     \
        next_trie_instruction(node)
#endif /* TRIE_COMPACT_PAIRS */



/* ------------------------ **
**      trie_extension      **
** ------------------------ */

#define stack_trie_extension_instr()                               \
        *aux_stack_ptr-- = 0;  /* float/longint extension mark */  \
        *aux_stack_ptr-- = TrNode_entry(node);                     \
        *aux_stack_ptr = heap_arity + 2;                           \
        YENV = aux_stack_ptr;                                      \
        next_trie_instruction(node)



/* ---------------------------- **
**      trie_float_longint      **
** ---------------------------- */

#define stack_trie_float_longint_instr()                         \
        if (heap_arity) {                                        \
          YENV = ++aux_stack_ptr;                                \
          Bind_Global((CELL *) *aux_stack_ptr, t);               \
          *aux_stack_ptr = heap_arity - 1;                       \
          next_instruction(heap_arity - 1 || subs_arity, node);  \
        } else {                                                 \
          int i;                                                 \
          YENV = aux_stack_ptr;                                  \
          *aux_stack_ptr = 0;                                    \
          aux_stack_ptr += 2;                                    \
          *aux_stack_ptr = subs_arity - 1;                       \
          aux_stack_ptr += subs_arity;                           \
          Bind((CELL *) *aux_stack_ptr, t);                      \
          for (i = 0; i < vars_arity; i++) {                     \
            *aux_stack_ptr = *(aux_stack_ptr + 1);               \
            aux_stack_ptr++;                                     \
          }                                                      \
	        next_instruction(subs_arity - 1, node);                \
        }



/* --------------------------- **
**      Trie instructions      **
** --------------------------- */

  PBOp(trie_do_null, e)
    dprintf("trie_do_null\n");
#ifndef GLOBAL_TRIE
    register ans_node_ptr node = (ans_node_ptr) PREG;

    stack_trie_null_instr();
#else
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_do_null)");
#endif /* GLOBAL_TRIE */
  ENDPBOp();


  PBOp(trie_trust_null, e)
    dprintf("trie_trust_null\n");
#ifndef GLOBAL_TRIE
    register ans_node_ptr node = (ans_node_ptr) PREG;
    register CELL *aux_stack_ptr = (CELL *) (B + 1);
    int heap_arity = *aux_stack_ptr;
    int vars_arity = *(aux_stack_ptr + heap_arity + 1);
    int subs_arity = *(aux_stack_ptr + heap_arity + 2);

    pop_trie_node();
    stack_trie_null_instr();
#else
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_trust_null)");
#endif /* GLOBAL_TRIE */
  ENDPBOp();


  PBOp(trie_try_null, e)
    dprintf("trie_try_null\n");
#ifndef GLOBAL_TRIE
    register ans_node_ptr node = (ans_node_ptr) PREG;
    register CELL *aux_stack_ptr = YENV;
    int heap_arity = *aux_stack_ptr;
    int vars_arity = *(aux_stack_ptr + heap_arity + 1);
    int subs_arity = *(aux_stack_ptr + heap_arity + 2);

    store_trie_node(TrNode_next(node));
    stack_trie_null_instr();
#else
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_try_null)");
#endif /* GLOBAL_TRIE */
  ENDPBOp();


  PBOp(trie_retry_null, e)
    dprintf("trie_retry_null\n");
#ifndef GLOBAL_TRIE
    register ans_node_ptr node = (ans_node_ptr) PREG;
    register CELL *aux_stack_ptr = (CELL *) (B + 1);
    int heap_arity = *aux_stack_ptr;
    int vars_arity = *(aux_stack_ptr + heap_arity + 1);
    int subs_arity = *(aux_stack_ptr + heap_arity + 2);

    restore_trie_node(TrNode_next(node));
    stack_trie_null_instr();
#else
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_retry_null)");
#endif /* GLOBAL_TRIE */
  ENDPBOp();


  PBOp(trie_do_null_in_new_pair, e)
    dprintf("trie_do_null_in_new_pair\n");
#if defined(TRIE_COMPACT_PAIRS) && !defined(GLOBAL_TRIE)
    register ans_node_ptr node = (ans_node_ptr) PREG;
    register CELL *aux_stack_ptr = YENV;
    int heap_arity = *aux_stack_ptr;
    int vars_arity = *(aux_stack_ptr + heap_arity + 1);
    int subs_arity = *(aux_stack_ptr + heap_arity + 2);

    stack_trie_null_in_new_pair_instr();
#else
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_do_null_in_new_pair)");
#endif /* TRIE_COMPACT_PAIRS && GLOBAL_TRIE */
  ENDPBOp();


  PBOp(trie_trust_null_in_new_pair, e)
    dprintf("trie_trust_null_in_new_pair\n");
#if defined(TRIE_COMPACT_PAIRS) && !defined(GLOBAL_TRIE)
    register ans_node_ptr node = (ans_node_ptr) PREG;
    register CELL *aux_stack_ptr = (CELL *) (B + 1);
    int heap_arity = *aux_stack_ptr;
    int vars_arity = *(aux_stack_ptr + heap_arity + 1);
    int subs_arity = *(aux_stack_ptr + heap_arity + 2);

    pop_trie_node();
    stack_trie_null_in_new_pair_instr();
#else
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_trust_null_in_new_pair)");
#endif /* TRIE_COMPACT_PAIRS && GLOBAL_TRIE */
  ENDPBOp();


  PBOp(trie_try_null_in_new_pair, e)
    dprintf("trie_try_null_in_new_pair\n");
#if defined(TRIE_COMPACT_PAIRS) && !defined(GLOBAL_TRIE)
    register ans_node_ptr node = (ans_node_ptr) PREG;
    register CELL *aux_stack_ptr = YENV;
    int heap_arity = *aux_stack_ptr;
    int vars_arity = *(aux_stack_ptr + heap_arity + 1);
    int subs_arity = *(aux_stack_ptr + heap_arity + 2);

    store_trie_node(TrNode_next(node));
    stack_trie_null_in_new_pair_instr();
#else
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_try_null_in_new_pair)");
#endif /* TRIE_COMPACT_PAIRS && GLOBAL_TRIE */
  ENDPBOp();


  PBOp(trie_retry_null_in_new_pair, e)
    dprintf("trie_retry_null_in_new_pair\n");
#if defined(TRIE_COMPACT_PAIRS) && !defined(GLOBAL_TRIE)
    register ans_node_ptr node = (ans_node_ptr) PREG;
    register CELL *aux_stack_ptr = (CELL *) (B + 1);
    int heap_arity = *aux_stack_ptr;
    int vars_arity = *(aux_stack_ptr + heap_arity + 1);
    int subs_arity = *(aux_stack_ptr + heap_arity + 2);

    restore_trie_node(TrNode_next(node));
    stack_trie_null_in_new_pair_instr();
#else
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_retry_null_in_new_pair)");
#endif /* TRIE_COMPACT_PAIRS && GLOBAL_TRIE */
  ENDPBOp();


  PBOp(trie_do_var, e)
    dprintf("trie_do_var\n");
#ifndef GLOBAL_TRIE
    register ans_node_ptr node = (ans_node_ptr) PREG;
    register CELL *aux_stack_ptr = YENV;
    int heap_arity = *aux_stack_ptr;
    int vars_arity = *(aux_stack_ptr + heap_arity + 1);
    int subs_arity = *(aux_stack_ptr + heap_arity + 2);

    stack_trie_var_instr();
#else
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_do_var)");
#endif /* GLOBAL_TRIE */
  ENDPBOp();


  PBOp(trie_trust_var, e)
    dprintf("trie_trust_var\n");
#ifndef GLOBAL_TRIE
    register ans_node_ptr node = (ans_node_ptr) PREG;
    register CELL *aux_stack_ptr = (CELL *) (B + 1);
    int heap_arity = *aux_stack_ptr;
    int vars_arity = *(aux_stack_ptr + heap_arity + 1);
    int subs_arity = *(aux_stack_ptr + heap_arity + 2);

    pop_trie_node();
    stack_trie_var_instr();
#else
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_trust_var)");
#endif /* GLOBAL_TRIE */
  ENDPBOp();


  PBOp(trie_try_var, e)
    dprintf("trie_try_var\n");
#ifndef GLOBAL_TRIE
    register ans_node_ptr node = (ans_node_ptr) PREG;
    register CELL *aux_stack_ptr = YENV;
    int heap_arity = *aux_stack_ptr;
    int vars_arity = *(aux_stack_ptr + heap_arity + 1);
    int subs_arity = *(aux_stack_ptr + heap_arity + 2);

    store_trie_node(TrNode_next(node));
    stack_trie_var_instr();
#else
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_try_var)");
#endif /* GLOBAL_TRIE */
  ENDPBOp();


  PBOp(trie_retry_var, e)
    dprintf("trie_retry_var\n");
#ifndef GLOBAL_TRIE
    register ans_node_ptr node = (ans_node_ptr) PREG;
    register CELL *aux_stack_ptr = (CELL *) (B + 1);
    int heap_arity = *aux_stack_ptr;
    int vars_arity = *(aux_stack_ptr + heap_arity + 1);
    int subs_arity = *(aux_stack_ptr + heap_arity + 2);

    restore_trie_node(TrNode_next(node));
    stack_trie_var_instr();
#else
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_retry_var)");
#endif /* GLOBAL_TRIE */
  ENDPBOp();


  PBOp(trie_do_var_in_new_pair, e)
    dprintf("trie_do_var_in_new_pair\n");
#if defined(TRIE_COMPACT_PAIRS) && !defined(GLOBAL_TRIE)
    register ans_node_ptr node = (ans_node_ptr) PREG;
    register CELL *aux_stack_ptr = YENV;
    int heap_arity = *aux_stack_ptr;
    int vars_arity = *(aux_stack_ptr + heap_arity + 1);
    int subs_arity = *(aux_stack_ptr + heap_arity + 2);

    stack_trie_var_in_new_pair_instr();
#else
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_do_var_in_new_pair)");
#endif /* TRIE_COMPACT_PAIRS && GLOBAL_TRIE */
  ENDPBOp();


  PBOp(trie_trust_var_in_new_pair, e)
    dprintf("trie_trust_var_in_new_pair\n");
#if defined(TRIE_COMPACT_PAIRS) && !defined(GLOBAL_TRIE)
    register ans_node_ptr node = (ans_node_ptr) PREG;
    register CELL *aux_stack_ptr = (CELL *) (B + 1);
    int heap_arity = *aux_stack_ptr;
    int vars_arity = *(aux_stack_ptr + heap_arity + 1);
    int subs_arity = *(aux_stack_ptr + heap_arity + 2);

    pop_trie_node();
    stack_trie_var_in_new_pair_instr();
#else
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_trust_var_in_new_pair)");
#endif /* TRIE_COMPACT_PAIRS && GLOBAL_TRIE */
  ENDPBOp();


  PBOp(trie_try_var_in_new_pair, e)
    dprintf("trie_try_var_in_new_pair\n");
#if defined(TRIE_COMPACT_PAIRS) && !defined(GLOBAL_TRIE)
    register ans_node_ptr node = (ans_node_ptr) PREG;
    register CELL *aux_stack_ptr = YENV;
    int heap_arity = *aux_stack_ptr;
    int vars_arity = *(aux_stack_ptr + heap_arity + 1);
    int subs_arity = *(aux_stack_ptr + heap_arity + 2);

    store_trie_node(TrNode_next(node));
    stack_trie_var_in_new_pair_instr();
#else
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_try_var_in_new_pair)");
#endif /* TRIE_COMPACT_PAIRS && GLOBAL_TRIE */
  ENDPBOp();


  PBOp(trie_retry_var_in_new_pair, e)
    dprintf("trie_retry_var_in_new_pair\n");
#if defined(TRIE_COMPACT_PAIRS) && !defined(GLOBAL_TRIE)
    register ans_node_ptr node = (ans_node_ptr) PREG;
    register CELL *aux_stack_ptr = (CELL *) (B + 1);
    int heap_arity = *aux_stack_ptr;
    int vars_arity = *(aux_stack_ptr + heap_arity + 1);
    int subs_arity = *(aux_stack_ptr + heap_arity + 2);

    restore_trie_node(TrNode_next(node));
    stack_trie_var_in_new_pair_instr();
#else
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_retry_var_in_new_pair)");
#endif /* TRIE_COMPACT_PAIRS && GLOBAL_TRIE */
  ENDPBOp();


  PBOp(trie_do_val, e)
    dprintf("trie_do_val\n");
#ifndef GLOBAL_TRIE
    register ans_node_ptr node = (ans_node_ptr) PREG;
    register CELL *aux_stack_ptr = YENV;
    int heap_arity = *aux_stack_ptr;
    int vars_arity = *(aux_stack_ptr + heap_arity + 1);
    int subs_arity = *(aux_stack_ptr + heap_arity + 2);
    int var_index = VarIndexOfTableTerm(TrNode_entry(node));

    stack_trie_val_instr();
#else
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_do_val)");
#endif /* GLOBAL_TRIE */
  ENDPBOp();


  PBOp(trie_trust_val, e)
    dprintf("trie_trust_val\n");
#ifndef GLOBAL_TRIE
    register ans_node_ptr node = (ans_node_ptr) PREG;
    register CELL *aux_stack_ptr = (CELL *) (B + 1);
    int heap_arity = *aux_stack_ptr;
    int vars_arity = *(aux_stack_ptr + heap_arity + 1);
    int subs_arity = *(aux_stack_ptr + heap_arity + 2);
    int var_index = VarIndexOfTableTerm(TrNode_entry(node));

    pop_trie_node();
    stack_trie_val_instr();
#else
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_trust_val)");
#endif /* GLOBAL_TRIE */
  ENDPBOp();


  PBOp(trie_try_val, e)
    dprintf("trie_try_val\n");
#ifndef GLOBAL_TRIE
    register ans_node_ptr node = (ans_node_ptr) PREG;
    register CELL *aux_stack_ptr = YENV;
    int heap_arity = *aux_stack_ptr;
    int vars_arity = *(aux_stack_ptr + heap_arity + 1);
    int subs_arity = *(aux_stack_ptr + heap_arity + 2);
    int var_index = VarIndexOfTableTerm(TrNode_entry(node));

    store_trie_node(TrNode_next(node));
    stack_trie_val_instr();
#else
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_try_val)");
#endif /* GLOBAL_TRIE */
  ENDPBOp();


  PBOp(trie_retry_val, e)
    dprintf("trie_retry_val\n");
#ifndef GLOBAL_TRIE
    register ans_node_ptr node = (ans_node_ptr) PREG;
    register CELL *aux_stack_ptr = (CELL *) (B + 1);
    int heap_arity = *aux_stack_ptr;
    int vars_arity = *(aux_stack_ptr + heap_arity + 1);
    int subs_arity = *(aux_stack_ptr + heap_arity + 2);
    int var_index = VarIndexOfTableTerm(TrNode_entry(node));

    restore_trie_node(TrNode_next(node));
    stack_trie_val_instr();
#else
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_retry_val)");
#endif /* GLOBAL_TRIE */
  ENDPBOp();


  PBOp(trie_do_val_in_new_pair, e)
    dprintf("trie_do_val_in_new_pair\n");
#if defined(TRIE_COMPACT_PAIRS) && !defined(GLOBAL_TRIE)
    register ans_node_ptr node = (ans_node_ptr) PREG;
    register CELL *aux_stack_ptr = YENV;
    int heap_arity = *aux_stack_ptr;
    int vars_arity = *(aux_stack_ptr + heap_arity + 1);
    int subs_arity = *(aux_stack_ptr + heap_arity + 2);
    int var_index = VarIndexOfTableTerm(TrNode_entry(node));

    stack_trie_val_in_new_pair_instr();
#else
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_do_val_in_new_pair)");
#endif /* TRIE_COMPACT_PAIRS && GLOBAL_TRIE */
  ENDPBOp();


  PBOp(trie_trust_val_in_new_pair, e)
    dprintf("trie_trust_val_in_pair\n");
#if defined(TRIE_COMPACT_PAIRS) && !defined(GLOBAL_TRIE)
    register ans_node_ptr node = (ans_node_ptr) PREG;
    register CELL *aux_stack_ptr = (CELL *) (B + 1);
    int heap_arity = *aux_stack_ptr;
    int vars_arity = *(aux_stack_ptr + heap_arity + 1);
    int subs_arity = *(aux_stack_ptr + heap_arity + 2);
    int var_index = VarIndexOfTableTerm(TrNode_entry(node));

    pop_trie_node();
    stack_trie_val_in_new_pair_instr();
#else
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_trust_val_in_new_pair)");
#endif /* TRIE_COMPACT_PAIRS && GLOBAL_TRIE */
  ENDPBOp();


  PBOp(trie_try_val_in_new_pair, e)
    dprintf("trie_retry_val_in_new_pair\n");
#if defined(TRIE_COMPACT_PAIRS) && !defined(GLOBAL_TRIE)
    register ans_node_ptr node = (ans_node_ptr) PREG;
    register CELL *aux_stack_ptr = YENV;
    int heap_arity = *aux_stack_ptr;
    int vars_arity = *(aux_stack_ptr + heap_arity + 1);
    int subs_arity = *(aux_stack_ptr + heap_arity + 2);
    int var_index = VarIndexOfTableTerm(TrNode_entry(node));

    store_trie_node(TrNode_next(node));
    stack_trie_val_in_new_pair_instr();
#else
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_try_val_in_new_pair)");
#endif /* TRIE_COMPACT_PAIRS && GLOBAL_TRIE */
  ENDPBOp();


  PBOp(trie_retry_val_in_new_pair, e)
    dprintf("trie_retry_val_in_new_pair\n");
#if defined(TRIE_COMPACT_PAIRS) && !defined(GLOBAL_TRIE)
    register ans_node_ptr node = (ans_node_ptr) PREG;
    register CELL *aux_stack_ptr = (CELL *) (B + 1);
    int heap_arity = *aux_stack_ptr;
    int vars_arity = *(aux_stack_ptr + heap_arity + 1);
    int subs_arity = *(aux_stack_ptr + heap_arity + 2);
    int var_index = VarIndexOfTableTerm(TrNode_entry(node));

    restore_trie_node(TrNode_next(node));
    stack_trie_val_in_new_pair_instr();
#else
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_retry_val_in_new_pair)");
#endif /* TRIE_COMPACT_PAIRS && GLOBAL_TRIE */
  ENDPBOp();


  PBOp(trie_do_atom, e)
    dprintf("trie_do_atom\n");
    register ans_node_ptr node = (ans_node_ptr) PREG;
    register CELL *aux_stack_ptr = YENV;
#ifdef GLOBAL_TRIE
    int subs_arity = *(aux_stack_ptr + *aux_stack_ptr + 1);
    YENV = aux_stack_ptr = load_substitution_variable(TrNode_entry(node), aux_stack_ptr);
    next_instruction(subs_arity - 1 , node);
#else
    int heap_arity = *aux_stack_ptr;
    int vars_arity = *(aux_stack_ptr + heap_arity + 1);
    int subs_arity = *(aux_stack_ptr + heap_arity + 2);

    stack_trie_atom_instr();
#endif /* GLOBAL_TRIE */
  ENDPBOp();


  PBOp(trie_trust_atom, e)
    dprintf("trie_trust_atom\n");
    register ans_node_ptr node = (ans_node_ptr) PREG;
    register CELL *aux_stack_ptr = (CELL *) (B + 1);
#ifdef GLOBAL_TRIE
    int vars_arity = *(aux_stack_ptr);
    int subs_arity = *(aux_stack_ptr + vars_arity + 1);
#else
    int heap_arity = *aux_stack_ptr;
    int vars_arity = *(aux_stack_ptr + heap_arity + 1);
    int subs_arity = *(aux_stack_ptr + heap_arity + 2);
#endif /* GLOBAL_TRIE */
    pop_trie_node();
#ifdef GLOBAL_TRIE
    YENV = aux_stack_ptr = load_substitution_variable(TrNode_entry(node), aux_stack_ptr);
    next_instruction(subs_arity - 1 , node);
#else
    stack_trie_atom_instr();
#endif /* GLOBAL_TRIE */
  ENDPBOp();


  PBOp(trie_try_atom, e)
    dprintf("trie_try_atom\n");
    register ans_node_ptr node = (ans_node_ptr) PREG;
    register CELL *aux_stack_ptr = YENV;
#ifdef GLOBAL_TRIE
    int vars_arity = *(aux_stack_ptr);
    int subs_arity = *(aux_stack_ptr + vars_arity + 1);
#else
    int heap_arity = *aux_stack_ptr;
    int vars_arity = *(aux_stack_ptr + heap_arity + 1);
    int subs_arity = *(aux_stack_ptr + heap_arity + 2);
#endif /* GLOBAL_TRIE */
    store_trie_node(TrNode_next(node));
#ifdef GLOBAL_TRIE
    YENV = aux_stack_ptr = load_substitution_variable(TrNode_entry(node), aux_stack_ptr);
    next_instruction(subs_arity - 1, node); 
#else
    stack_trie_atom_instr();
#endif /* GLOBAL_TRIE */    
  ENDPBOp();


  PBOp(trie_retry_atom, e)
    dprintf("trie_retry_atom\n");
    register ans_node_ptr node = (ans_node_ptr) PREG;
    register CELL *aux_stack_ptr = (CELL *) (B + 1);
#ifdef GLOBAL_TRIE
    int vars_arity = *(aux_stack_ptr);
    int subs_arity = *(aux_stack_ptr + vars_arity + 1);
#else
    int heap_arity = *aux_stack_ptr;
    int vars_arity = *(aux_stack_ptr + heap_arity + 1);
    int subs_arity = *(aux_stack_ptr + heap_arity + 2);
#endif /* GLOBAL_TRIE */
    restore_trie_node(TrNode_next(node));
#ifdef GLOBAL_TRIE
    YENV = aux_stack_ptr = load_substitution_variable(TrNode_entry(node), aux_stack_ptr);
    next_instruction(subs_arity - 1, node); 
#else
    stack_trie_atom_instr();
#endif /* GLOBAL_TRIE */
  ENDPBOp();


  PBOp(trie_do_atom_in_new_pair, e)
    dprintf("trie_do_atom_in_new_pair\n");
#if defined(TRIE_COMPACT_PAIRS) && !defined(GLOBAL_TRIE)
    register ans_node_ptr node = (ans_node_ptr) PREG;
    register CELL *aux_stack_ptr = YENV;
    int heap_arity = *aux_stack_ptr;
    int vars_arity = *(aux_stack_ptr + heap_arity + 1);
    int subs_arity = *(aux_stack_ptr + heap_arity + 2);

    stack_trie_atom_in_new_pair_instr();
#else
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_do_atom_in_new_pair)");
#endif /* TRIE_COMPACT_PAIRS && GLOBAL_TRIE */
  ENDPBOp();


  PBOp(trie_trust_atom_in_new_pair, e)
    dprintf("trie_trust_atom_in_new_pair\n");
#if defined(TRIE_COMPACT_PAIRS) && !defined(GLOBAL_TRIE)
    register ans_node_ptr node = (ans_node_ptr) PREG;
    register CELL *aux_stack_ptr = (CELL *) (B + 1);
    int heap_arity = *aux_stack_ptr;
    int vars_arity = *(aux_stack_ptr + heap_arity + 1);
    int subs_arity = *(aux_stack_ptr + heap_arity + 2);

    pop_trie_node();
    stack_trie_atom_in_new_pair_instr();
#else
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_trust_atom_in_new_pair)");
#endif /* TRIE_COMPACT_PAIRS && GLOBAL_TRIE */
  ENDPBOp();


  PBOp(trie_try_atom_in_new_pair, e)
    dprintf("trie_try_atom_in_new_pair\n");
#if defined(TRIE_COMPACT_PAIRS) && !defined(GLOBAL_TRIE)
    register ans_node_ptr node = (ans_node_ptr) PREG;
    register CELL *aux_stack_ptr = YENV;
    int heap_arity = *aux_stack_ptr;
    int vars_arity = *(aux_stack_ptr + heap_arity + 1);
    int subs_arity = *(aux_stack_ptr + heap_arity + 2);

    store_trie_node(TrNode_next(node));
    stack_trie_atom_in_new_pair_instr();
#else
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_try_atom_in_new_pair)");
#endif /* TRIE_COMPACT_PAIRS && GLOBAL_TRIE */
  ENDPBOp();


  PBOp(trie_retry_atom_in_new_pair, e)
    dprintf("trie_retry_atom_in_new_pair\n");
#if defined(TRIE_COMPACT_PAIRS) && !defined(GLOBAL_TRIE)
    register ans_node_ptr node = (ans_node_ptr) PREG;
    register CELL *aux_stack_ptr = (CELL *) (B + 1);
    int heap_arity = *aux_stack_ptr;
    int vars_arity = *(aux_stack_ptr + heap_arity + 1);
    int subs_arity = *(aux_stack_ptr + heap_arity + 2);

    restore_trie_node(TrNode_next(node));
    stack_trie_atom_in_new_pair_instr();
#else
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_retry_atom_in_new_pair)");
#endif /* TRIE_COMPACT_PAIRS && GLOBAL_TRIE */
  ENDPBOp();


  PBOp(trie_do_pair, e)
    dprintf("trie_do_pair\n");
#ifndef GLOBAL_TRIE
    register ans_node_ptr node = (ans_node_ptr) PREG;
    register CELL *aux_stack_ptr = YENV;
    int heap_arity = *aux_stack_ptr;
    int vars_arity = *(aux_stack_ptr + heap_arity + 1);
    int subs_arity = *(aux_stack_ptr + heap_arity + 2);

    stack_trie_pair_instr();
#else
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_do_pair)");
#endif /* GLOBAL_TRIE */
  ENDPBOp();


  PBOp(trie_trust_pair, e)
    dprintf("trie_trust_pair\n");
#ifndef GLOBAL_TRIE
    register ans_node_ptr node = (ans_node_ptr) PREG;
    register CELL *aux_stack_ptr = (CELL *) (B + 1);
    int heap_arity = *aux_stack_ptr;
    int vars_arity = *(aux_stack_ptr + heap_arity + 1);
    int subs_arity = *(aux_stack_ptr + heap_arity + 2);

    pop_trie_node();
    stack_trie_pair_instr();
#else
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_trust_pair)");
#endif /* GLOBAL_TRIE */
  ENDPBOp();


  PBOp(trie_try_pair, e)
    dprintf("trie_try_pair\n");
#ifndef GLOBAL_TRIE
    register ans_node_ptr node = (ans_node_ptr) PREG;
    register CELL *aux_stack_ptr = YENV;
    int heap_arity = *aux_stack_ptr;
    int vars_arity = *(aux_stack_ptr + heap_arity + 1);
    int subs_arity = *(aux_stack_ptr + heap_arity + 2);

    store_trie_node(TrNode_next(node));
    stack_trie_pair_instr();
#else
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_try_pair)");
#endif /* GLOBAL_TRIE */
  ENDPBOp();


  PBOp(trie_retry_pair, e)
    dprintf("trie_retry_pair\n");
#ifndef GLOBAL_TRIE
    register ans_node_ptr node = (ans_node_ptr) PREG;
    register CELL *aux_stack_ptr = (CELL *) (B + 1);
    int heap_arity = *aux_stack_ptr;
    int vars_arity = *(aux_stack_ptr + heap_arity + 1);
    int subs_arity = *(aux_stack_ptr + heap_arity + 2);

    restore_trie_node(TrNode_next(node));
    stack_trie_pair_instr();
#else
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_retry_pair)");
#endif /* GLOBAL_TRIE */
  ENDPBOp();


  PBOp(trie_do_struct, e)
    dprintf("trie_do_struct\n");
#ifndef GLOBAL_TRIE
    register ans_node_ptr node = (ans_node_ptr) PREG;
    register CELL *aux_stack_ptr = YENV;
    int heap_arity = *aux_stack_ptr;
    int vars_arity = *(aux_stack_ptr + heap_arity + 1);
    int subs_arity = *(aux_stack_ptr + heap_arity + 2);
    Functor func = (Functor) RepAppl(TrNode_entry(node));
    int func_arity = ArityOfFunctor(func);

    stack_trie_struct_instr();
#else
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_do_struct)");
#endif /* GLOBAL_TRIE */
  ENDPBOp();


  PBOp(trie_trust_struct, e)
    dprintf("trie_trust_struct\n");
#ifndef GLOBAL_TRIE
    register ans_node_ptr node = (ans_node_ptr) PREG;
    register CELL *aux_stack_ptr = (CELL *) (B + 1);
    int heap_arity = *aux_stack_ptr;
    int vars_arity = *(aux_stack_ptr + heap_arity + 1);
    int subs_arity = *(aux_stack_ptr + heap_arity + 2);
    Functor func = (Functor) RepAppl(TrNode_entry(node));
    int func_arity = ArityOfFunctor(func);

    pop_trie_node();
    stack_trie_struct_instr();
#else
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_trust_struct)");
#endif /* GLOBAL_TRIE */
  ENDPBOp();


  PBOp(trie_try_struct, e)
    dprintf("trie_try_struct\n");
#ifndef GLOBAL_TRIE
    register ans_node_ptr node = (ans_node_ptr) PREG;
    register CELL *aux_stack_ptr = YENV;
    int heap_arity = *aux_stack_ptr;
    int vars_arity = *(aux_stack_ptr + heap_arity + 1);
    int subs_arity = *(aux_stack_ptr + heap_arity + 2);
    Functor func = (Functor) RepAppl(TrNode_entry(node));
    int func_arity = ArityOfFunctor(func);

    store_trie_node(TrNode_next(node));
    stack_trie_struct_instr();
#else
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_try_struct)");
#endif /* GLOBAL_TRIE */
  ENDPBOp();


  PBOp(trie_retry_struct, e)
    dprintf("trie_retry_struct\n");
#ifndef GLOBAL_TRIE
    register ans_node_ptr node = (ans_node_ptr) PREG;
    register CELL *aux_stack_ptr = (CELL *) (B + 1);
    int heap_arity = *aux_stack_ptr;
    int vars_arity = *(aux_stack_ptr + heap_arity + 1);
    int subs_arity = *(aux_stack_ptr + heap_arity + 2);
    Functor func = (Functor) RepAppl(TrNode_entry(node));
    int func_arity = ArityOfFunctor(func);

    restore_trie_node(TrNode_next(node));
    stack_trie_struct_instr();
#else
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_retry_struct)");
#endif /* GLOBAL_TRIE */
  ENDPBOp();


  PBOp(trie_do_struct_in_new_pair, e)
    dprintf("trie_do_struct_in_new_pair\n");
#if defined(TRIE_COMPACT_PAIRS) && !defined(GLOBAL_TRIE)
    register ans_node_ptr node = (ans_node_ptr) PREG;
    register CELL *aux_stack_ptr = YENV;
    int heap_arity = *aux_stack_ptr;
    int vars_arity = *(aux_stack_ptr + heap_arity + 1);
    int subs_arity = *(aux_stack_ptr + heap_arity + 2);
    Functor func = (Functor) RepAppl(TrNode_entry(node));
    int func_arity = ArityOfFunctor(func);

    stack_trie_struct_in_new_pair_instr();
#else
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_do_struct_in_new_pair)");
#endif /* TRIE_COMPACT_PAIRS && GLOBAL_TRIE */
  ENDPBOp();


  PBOp(trie_trust_struct_in_new_pair, e)
    dprintf("trie_trust_struct_in_new_pair\n");
#if defined(TRIE_COMPACT_PAIRS) && !defined(GLOBAL_TRIE)
    register ans_node_ptr node = (ans_node_ptr) PREG;
    register CELL *aux_stack_ptr = (CELL *) (B + 1);
    int heap_arity = *aux_stack_ptr;
    int vars_arity = *(aux_stack_ptr + heap_arity + 1);
    int subs_arity = *(aux_stack_ptr + heap_arity + 2);
    Functor func = (Functor) RepAppl(TrNode_entry(node));
    int func_arity = ArityOfFunctor(func);

    pop_trie_node();
    stack_trie_struct_in_new_pair_instr();
#else
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_trust_struct_in_new_pair)");
#endif /* TRIE_COMPACT_PAIRS && GLOBAL_TRIE */
  ENDPBOp();


  PBOp(trie_try_struct_in_new_pair, e)
    dprintf("trie_try_struct_in_new_pair\n");
#if defined(TRIE_COMPACT_PAIRS) && !defined(GLOBAL_TRIE)
    register ans_node_ptr node = (ans_node_ptr) PREG;
    register CELL *aux_stack_ptr = YENV;
    int heap_arity = *aux_stack_ptr;
    int vars_arity = *(aux_stack_ptr + heap_arity + 1);
    int subs_arity = *(aux_stack_ptr + heap_arity + 2);
    Functor func = (Functor) RepAppl(TrNode_entry(node));
    int func_arity = ArityOfFunctor(func);

    store_trie_node(TrNode_next(node));
    stack_trie_struct_in_new_pair_instr();
#else
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_try_struct_in_new_pair)");
#endif /* TRIE_COMPACT_PAIRS && GLOBAL_TRIE */
  ENDPBOp();


  PBOp(trie_retry_struct_in_new_pair, e)
    dprintf("trie_retry_struct_in_new_pair\n");
#if defined(TRIE_COMPACT_PAIRS) && !defined(GLOBAL_TRIE)
    register ans_node_ptr node = (ans_node_ptr) PREG;
    register CELL *aux_stack_ptr = (CELL *) (B + 1);
    int heap_arity = *aux_stack_ptr;
    int vars_arity = *(aux_stack_ptr + heap_arity + 1);
    int subs_arity = *(aux_stack_ptr + heap_arity + 2);
    Functor func = (Functor) RepAppl(TrNode_entry(node));
    int func_arity = ArityOfFunctor(func);

    restore_trie_node(TrNode_next(node));
    stack_trie_struct_in_new_pair_instr();
#else
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_retry_struct_in_new_pair)");
#endif /* TRIE_COMPACT_PAIRS && GLOBAL_TRIE */
  ENDPBOp();


  PBOp(trie_do_extension, e)
    dprintf("trie_do_extension\n");
#ifndef GLOBAL_TRIE
    register ans_node_ptr node = (ans_node_ptr) PREG;
    register CELL *aux_stack_ptr = YENV;
    int heap_arity = *aux_stack_ptr;

    stack_trie_extension_instr();
#else
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_do_extension)");
#endif /* GLOBAL_TRIE */
  ENDPBOp();


  PBOp(trie_trust_extension, e)
    dprintf("trie_trust_extension\n");
#ifndef GLOBAL_TRIE
    register ans_node_ptr node = (ans_node_ptr) PREG;
    register CELL *aux_stack_ptr = (CELL *) (B + 1);
    int heap_arity = *aux_stack_ptr;
    int vars_arity = *(aux_stack_ptr + heap_arity + 1);
    int subs_arity = *(aux_stack_ptr + heap_arity + 2);

    pop_trie_node();
    stack_trie_extension_instr();
#else
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_trust_extension)");
#endif /* GLOBAL_TRIE */
  ENDPBOp();


  PBOp(trie_try_extension, e)
    dprintf("trie_try_extension\n");
#ifndef GLOBAL_TRIE
    register ans_node_ptr node = (ans_node_ptr) PREG;
    register CELL *aux_stack_ptr = YENV;
    int heap_arity = *aux_stack_ptr;
    int vars_arity = *(aux_stack_ptr + heap_arity + 1);
    int subs_arity = *(aux_stack_ptr + heap_arity + 2);

    store_trie_node(TrNode_next(node));
    stack_trie_extension_instr();
#else
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_try_extension)");
#endif /* GLOBAL_TRIE */
  ENDPBOp();


  PBOp(trie_retry_extension, e)
    dprintf("trie_retry_extension\n");
#ifndef GLOBAL_TRIE
    register ans_node_ptr node = (ans_node_ptr) PREG;
    register CELL *aux_stack_ptr = (CELL *) (B + 1);
    int heap_arity = *aux_stack_ptr;
    int vars_arity = *(aux_stack_ptr + heap_arity + 1);
    int subs_arity = *(aux_stack_ptr + heap_arity + 2);

    restore_trie_node(TrNode_next(node));
    stack_trie_extension_instr();
#else
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_retry_extension)");
#endif /* GLOBAL_TRIE */
  ENDPBOp();


  PBOp(trie_do_float, e)
    dprintf("trie_do_float\n");
#ifndef GLOBAL_TRIE
    register ans_node_ptr node = (ans_node_ptr) PREG;
    register CELL *aux_stack_ptr = YENV;
    int heap_arity = *aux_stack_ptr;
    int vars_arity = *(aux_stack_ptr + heap_arity + 1);
    int subs_arity = *(aux_stack_ptr + heap_arity + 2);
    volatile Float dbl;
    volatile Term *t_dbl = (Term *)((void *) &dbl);
    Term t;

#if SIZEOF_DOUBLE == 2 * SIZEOF_INT_P
    heap_arity -= 4;
    t_dbl[0] = *++aux_stack_ptr;
    ++aux_stack_ptr;  /* jump the float/longint extension mark */
    t_dbl[1] = *++aux_stack_ptr;
#else /* SIZEOF_DOUBLE == SIZEOF_INT_P */
    heap_arity -= 2;
    *t_dbl = *++aux_stack_ptr;
#endif /* SIZEOF_DOUBLE x SIZEOF_INT_P */
    ++aux_stack_ptr;  /* jump the float/longint extension mark */
    t = MkFloatTerm(dbl);
    stack_trie_float_longint_instr();
#else
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_do_float)");
#endif /* GLOBAL_TRIE */
  ENDPBOp();


  BOp(trie_trust_float, e)
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_trust_float)");
  ENDBOp();


  BOp(trie_try_float, e)
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_try_float)");
  ENDBOp();

  BOp(trie_retry_float, e)
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_retry_float)");
  ENDBOp();
  
  BOp(trie_do_float_val, e)
#ifdef TABLING_CALL_SUBSUMPTION
    dprintf("trie_do_float_val\n");
    
    register tst_node_ptr node = (tst_node_ptr) PREG;
    register CELL *aux_stack_ptr = YENV;
    int heap_arity = *aux_stack_ptr;
    int vars_arity = *(aux_stack_ptr + heap_arity + 1);
    int subs_arity = *(aux_stack_ptr + heap_arity + 2);

    stack_trie_float_instr();
#else
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_do_float_val)");
#endif /* TABLING_CALL_SUBSUMPTION */
  ENDBOp();
  
  BOp(trie_trust_float_val, e)
#ifdef TABLING_CALL_SUBSUMPTION
    dprintf("trie_trust_float_val\n");
    register tst_node_ptr node = (tst_node_ptr) PREG;
    register CELL *aux_stack_ptr = (CELL *) (B + 1);
    int heap_arity = *aux_stack_ptr;
    int vars_arity = *(aux_stack_ptr + heap_arity + 1);
    int subs_arity = *(aux_stack_ptr + heap_arity + 2);
    
    pop_trie_node();
    
    stack_trie_float_instr();
#else
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_trust_float_val)");
#endif /* TABLING_CALL_SUBSUMPTION */
  ENDBOp();
  
  BOp(trie_try_float_val, e)
#ifdef TABLING_CALL_SUBSUMPTION
    dprintf("trie_try_float_val\n");
    register tst_node_ptr node = (tst_node_ptr) PREG;
    register CELL *aux_stack_ptr = YENV;
    int heap_arity = *aux_stack_ptr;
    int vars_arity = *(aux_stack_ptr + heap_arity + 1);
    int subs_arity = *(aux_stack_ptr + heap_arity + 2);
    
    store_trie_node(TrNode_next(node));
    
    stack_trie_float_instr();
#else
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_try_float_val)");
#endif /* TABLING_CALL_SUBSUMPTION */
  ENDBOp();
  
  BOp(trie_retry_float_val, e)
#ifdef TABLING_CALL_SUBSUMPTION
    dprintf("trie_retry_float\n");
    register tst_node_ptr node = (tst_node_ptr) PREG;
    register CELL *aux_stack_ptr = (CELL *) (B + 1);
    int heap_arity = *aux_stack_ptr;
    int vars_arity = *(aux_stack_ptr + heap_arity + 1);
    int subs_arity = *(aux_stack_ptr + heap_arity + 2);
    
    restore_trie_node(TrNode_next(node));
    
    stack_trie_float_instr();
#else
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_retry_float_val)");
#endif /* TABLING_CALL_SUBSUMPTION */
  ENDBOp();

  PBOp(trie_do_long, e)
    dprintf("trie_do_long\n");
#ifndef GLOBAL_TRIE
    register ans_node_ptr node = (ans_node_ptr) PREG;
    register CELL *aux_stack_ptr = YENV;
    int heap_arity = *aux_stack_ptr;
    int vars_arity = *(aux_stack_ptr + heap_arity + 1);
    int subs_arity = *(aux_stack_ptr + heap_arity + 2);
    Term t;

    heap_arity -= 2;
    t = MkLongIntTerm(*++aux_stack_ptr);
    ++aux_stack_ptr;  /* jump the float/longint extension mark */
    stack_trie_float_longint_instr();
#else
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_do_long)");
#endif /* GLOBAL_TRIE */
  ENDPBOp();


  BOp(trie_trust_long, e)
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_trust_long)");
  ENDBOp();

  BOp(trie_try_long, e)
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_try_long)");
  ENDBOp();

  BOp(trie_retry_long, e)
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_retry_long)");
  ENDBOp();
  
  BOp(trie_do_long_int, e)
#ifdef TABLING_CALL_SUBSUMPTION
    dprintf("trie_do_long_int\n");
    register tst_node_ptr node = (tst_node_ptr) PREG;
    register CELL *aux_stack_ptr = YENV;
    int heap_arity = *aux_stack_ptr;
    int vars_arity = *(aux_stack_ptr + heap_arity + 1);
    int subs_arity = *(aux_stack_ptr + heap_arity + 2);

    stack_trie_long_instr();
#else
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_do_long_int)");
#endif /* TABLING_CALL_SUBSUMPTION */
  ENDBOp();
  
  BOp(trie_trust_long_int, e)
#ifdef TABLING_CALL_SUBSUMPTION
    dprintf("trie_trust_long_int\n");
    register tst_node_ptr node = (tst_node_ptr) PREG;
    register CELL *aux_stack_ptr = (CELL *) (B + 1);
    int heap_arity = *aux_stack_ptr;
    int vars_arity = *(aux_stack_ptr + heap_arity + 1);
    int subs_arity = *(aux_stack_ptr + heap_arity + 2);
    
    pop_trie_node();
    
    stack_trie_long_instr();
#else
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_trust_long_int)");
#endif /* TABLING_CALL_SUBSUMPTION */
  ENDBOp();
  
  BOp(trie_try_long_int, e)
#ifdef TABLING_CALL_SUBSUMPTION
    dprintf("trie_try_long_int\n");
    register tst_node_ptr node = (tst_node_ptr) PREG;
    register CELL *aux_stack_ptr = YENV;
    int heap_arity = *aux_stack_ptr;
    int vars_arity = *(aux_stack_ptr + heap_arity + 1);
    int subs_arity = *(aux_stack_ptr + heap_arity + 2);
    store_trie_node(TrNode_next(node));
    
    stack_trie_long_instr();
#else
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_try_long_int)");
#endif /* TABLING_CALL_SUBSUMPTION */
  ENDBOp();
  
  BOp(trie_retry_long_int, e)
#ifdef TABLING_CALL_SUBSUMPTION
    dprintf("trie_retry_long_int\n");
    register tst_node_ptr node = (tst_node_ptr) PREG;
    register CELL *aux_stack_ptr = (CELL *) (B + 1);
    int heap_arity = *aux_stack_ptr;
    int vars_arity = *(aux_stack_ptr + heap_arity + 1);
    int subs_arity = *(aux_stack_ptr + heap_arity + 2);
    
    restore_trie_node(TrNode_next(node));
    
    stack_trie_long_instr();
#else
    Yap_Error(INTERNAL_ERROR, TermNil, "invalid instruction (trie_retry_long_int)");
#endif /* TABLING_CALL_SUBSUMPTION */
  ENDBOp();
  
#define store_hash_node()                         \
    { register choiceptr cp;                      \
      YENV = (CELL *)(HASH_CP(YENV) - 1);         \
      cp = NORM_CP(YENV);                         \
      HBREG = H;                                  \
      store_yaam_reg_cpdepth(cp);                 \
      cp->cp_tr = TR;                             \
      cp->cp_h = H;                               \
      cp->cp_b = B;                               \
      cp->cp_cp = CPREG;                          \
      cp->cp_ap = TRIE_RETRY_HASH;                \
      cp->cp_env = ENV;                           \
      B = cp;                                     \
      YAPOR_SET_LOAD(B);                          \
      SET_BB(B);                                  \
      TABLING_ERRORS_check_stack;                 \
    }                                             \
    if(heap_arity)                                \
      aux_stack_ptr--;                            \
    else                                          \
      aux_stack_ptr -= (2 + subs_arity);          \
    copy_arity_stack()
  
#define restore_hash_node()                               \
    /* restore choice point */                            \
    H = HBREG = PROTECT_FROZEN_H(B);                      \
    restore_yaam_reg_cpdepth(B);                          \
    CPREG = B->cp_cp;                                     \
    ENV = B->cp_env;                                      \
    YENV = (CELL *)PROTECT_FROZEN_B(B);                   \
    SET_BB(NORM_CP(YENV));                                \
    register CELL *aux_stack_ptr = (CELL *)(hash_cp + 1); \
    int heap_arity = *aux_stack_ptr;                      \
    int vars_arity = *(aux_stack_ptr + heap_arity + 1);   \
    int subs_arity = *(aux_stack_ptr + heap_arity + 2);   \
    copy_arity_stack()
    
#define pop_hash_node()  {                                      \
    YENV = (CELL *) PROTECT_FROZEN_B((choiceptr)(hash_cp + 1)); \
    H = PROTECT_FROZEN_H(B);                                    \
    pop_yaam_reg_cpdepth(B);                                    \
    CPREG = B->cp_cp;                                           \
    TABLING_close_alt(B);                                       \
    ENV = B->cp_env;                                            \
    B = B->cp_b;                                                \
    HBREG = PROTECT_FROZEN_H(B);                                \
    SET_BB(PROTECT_FROZEN_B(B));                                \
    if ((choiceptr) YENV == B_FZ) {                             \
      register CELL *aux_stack_ptr = (CELL *) (hash_cp + 1);    \
      int heap_arity = *aux_stack_ptr;                          \
      int vars_arity = *(aux_stack_ptr + heap_arity + 1);       \
      int subs_arity = *(aux_stack_ptr + heap_arity + 2);       \
      copy_arity_stack();                                       \
    }                                                           \
  }
  
  BOp(trie_do_hash, e)
#ifdef TABLING_CALL_SUBSUMPTION
    register tst_ans_hash_ptr hash = (tst_ans_hash_ptr) PREG;
    register CELL *aux_stack_ptr = YENV;
    int heap_arity = *aux_stack_ptr;
    int vars_arity = *(aux_stack_ptr + heap_arity + 1);
    int subs_arity = *(aux_stack_ptr + heap_arity + 2);
    
    if(heap_arity)
      aux_stack_ptr++;
    else
      aux_stack_ptr += 2 + subs_arity;
    
    CELL term = Deref(*aux_stack_ptr);
    
    if(IsVarTerm(term)) {
      tst_node_ptr *first_bucket = TSTHT_buckets(hash);
      tst_node_ptr *end_bucket = first_bucket + TSTHT_num_buckets(hash);
      tst_node_ptr *final_bucket = NULL;
      
      /* find last valid bucket */
      while(--end_bucket != first_bucket) {
        if(*end_bucket) {
          final_bucket = end_bucket;
          break;
        }
      }
      
      /* find first valid bucket */
      while(!*(first_bucket))
        first_bucket++;
      
      if(first_bucket == final_bucket) {
        /* only one valid bucket in hash table */
        next_node_instruction(first_bucket);
      }
      
      store_hash_node();
      
      hash_cp_ptr hash_cp = HASH_CP(B);
      
      hash_cp->last_bucket = first_bucket;
      hash_cp->final_bucket = final_bucket;
      
      next_node_instruction(*(hash_cp->last_bucket));
    } else {
      
      /* get hash code for the corresponding term type */
      switch(cell_tag(term)) {
        case TAG_ATOM:
        case TAG_INT:
          break;
        case TAG_STRUCT:
          term = EncodeTrieFunctor(term);
          break;
        case TAG_LIST:
          term = EncodeTrieList(term);
          break;
        case TAG_LONG_INT:
          term = (Term)LongIntOfTerm(term);
          break;
        case TAG_FLOAT:
          term = (Term)FloatOfTerm(term);
          break;
        default:
          Yap_Error(INTERNAL_ERROR, TermNil, "invalid term tag (trie_do_hash)");
          break;
      }
      
      int bucket_entry = HASH_ENTRY(term, Hash_seed(hash));
      tst_node_ptr *bucket_ptr = Hash_bucket(hash, bucket_entry);
      tst_node_ptr *var_bucket_ptr = Hash_bucket(hash, TRIEVAR_BUCKET);
      tst_node_ptr bucket = *bucket_ptr;
      tst_node_ptr var_bucket = *var_bucket_ptr;
      
      if(bucket == NULL && var_bucket == NULL)
        goto fail; /* no buckets found */
      
      if(var_bucket_ptr == bucket_ptr)
        var_bucket = NULL; /* skip duplicate buckets */
      
      if(bucket != NULL && var_bucket != NULL) {
        /* var and concrete bucket found, try concrete then var bucket */
        store_hash_node();

        hash_cp_ptr hash_cp = HASH_CP(B);
        
        hash_cp->final_bucket = NULL;
        hash_cp->last_bucket = (tst_node_ptr*)var_bucket;
        
        next_node_instruction(bucket);
      }
      
      /* run the only valid bucket */
      next_node_instruction(bucket ? bucket : var_bucket);
    }
#else
    Yap_Error(INTERNAL_ERROR, TermNil, "tabling by call subsumption not supported (trie_do_hash)");
#endif /* TABLING_CALL_SUBSUMPTION */
  ENDBOp();
  
  BOp(trie_retry_hash, e)
#ifdef TABLING_CALL_SUBSUMPTION
    hash_cp_ptr hash_cp = HASH_CP(B);
  
    if(hash_cp->final_bucket) {
      /* trying to unify with a variable */
      while(hash_cp->last_bucket++) {
        if(*(hash_cp->last_bucket)) {
          if(hash_cp->last_bucket == hash_cp->final_bucket) {
            pop_hash_node();
          } else {
            restore_hash_node();
          }
          next_node_instruction(*(hash_cp->last_bucket));
        }
      }
    } else {
      /* trying to unify with a concrete term
       * here, we just need to run the variable bucket code
       */
      pop_hash_node();
        
      next_node_instruction((tst_node_ptr)hash_cp->last_bucket);
    }
#else
    Yap_Error(INTERNAL_ERROR, TermNil, "tabling by call subsumption not supported (trie_retry_hash)");
#endif /* TABLING_CALL_SUBSUMPTION */
  ENDBOp();
