/**********************************************************************
                                                               
                       The OPTYap Prolog system                
  OPTYap extends the Yap Prolog system to support or-parallel tabling
                                                               
  Copyright:   R. Rocha and NCC - University of Porto, Portugal
  File:        tab.utils.h
                                                                     
**********************************************************************/

#include "Yap.h"
#include "tab.utils.h"
#include "Yatom.h"
#include "tab.macros.h"
#include "tab.tst.h"


typedef enum {
  PRINT_ANSWER_VAR,
  PRINT_VAR
} PrintVarType;

static
void symstkPrintNextTrieTerm(CTXTdeclc FILE *fp, xsbBool list_recursion)
{
  Cell symbol;
  
  if(SymbolStack_IsEmpty) {
    fprintf(fp, "<no subterm>");
    return;
  }
  
  SymbolStack_Pop(symbol);
  
  if(IsIntTerm(symbol)) {
    if(list_recursion)
      fprintf(fp, "|" IntegerFormatString "]", int_val(symbol));
    else
      fprintf(fp, IntegerFormatString, int_val(symbol));
  } else if(IsVarTerm(symbol)) {
    if(list_recursion)
      fprintf(fp, "|VAR" IntegerFormatString "]", DecodeTrieVar(symbol));
    else
      fprintf(fp, "VAR" IntegerFormatString, DecodeTrieVar(symbol));
  } else if(IsAtomTerm(symbol)) {
    char *string = string_val(symbol);
    
    if(list_recursion) {
      if(symbol == TermNil)
        fprintf(fp, "]");
      else
        fprintf(fp, "|%s]", string);
    }
    else
      fprintf(fp, "%s", string);
  } else if(IsApplTerm(symbol)) {
    Functor f = (Functor) RepAppl(symbol);
    
    if(f == FunctorDouble) {
      BTNptr node;
      Float flt = 0.0;
      
      SymbolStack_PopOther(node, BTNptr);
      
      if(TrNode_is_call(node))
        flt = TrNode_float((float_sg_node_ptr)node);
#ifdef TABLING_CALL_SUBSUMPTION
      else
        flt = TSTN_float((float_tst_node_ptr)node);
#endif /* TABLING_CALL_SUBSUMPTION */

      if(list_recursion)
        fprintf(fp, "|" FloatFormatString "]", flt);
      else
        fprintf(fp, FloatFormatString, flt);
        
    } else if(f == FunctorLongInt) {
      BTNptr node;
      Int li = 0;
      
      SymbolStack_PopOther(node, BTNptr);
      
      if(TrNode_is_call(node))
        li = TrNode_long_int((long_sg_node_ptr)node);
#ifdef TABLING_CALL_SUBSUMPTION
      else
        li = TSTN_long_int((long_tst_node_ptr)node);
#endif /* TABLING_CALL_SUBSUMPTION */

      if(list_recursion)
        fprintf(fp, "|" LongIntFormatString "]", li);
      else
        fprintf(fp, LongIntFormatString, li);
    } else {
      int i;
      
      if(list_recursion)
        fprintf(fp, "|");
      
      fprintf(fp, "%s(", get_name(f));
      for(i = 1; i < (int)get_arity(f); i++) {
        symstkPrintNextTrieTerm(CTXTc fp, FALSE);
        fprintf(fp, ",");
      }
      symstkPrintNextTrieTerm(CTXTc fp, FALSE);
      fprintf(fp, ")");
      if(list_recursion)
        fprintf(fp, "]");
    }
  } else if(IsPairTerm(symbol)) {
#ifdef TRIE_COMPACT_PAIRS
    if(symbol == CompactPairInit) {
      int cnt;
      
      fprintf(fp, "[");
      
      for(cnt = 0; ; ++cnt) {
        SymbolStack_Peek(symbol);
        
        if(symbol == CompactPairEndList) {
          SymbolStack_BlindDrop;
          if(cnt)
            fprintf(fp, ",");
          symstkPrintNextTrieTerm(CTXTc fp, FALSE);
          fprintf(fp, "]");
          break;
        } else if(symbol == CompactPairEndTerm) {
          SymbolStack_BlindDrop;
          if(cnt)
            fprintf(fp, "|");
          symstkPrintNextTrieTerm(CTXTc fp, FALSE);
          fprintf(fp, "]");
          break;
        }
        
        if(cnt)
          fprintf(fp, ",");
        
        symstkPrintNextTrieTerm(CTXTc fp, FALSE);
      }
    }
#else
    if(list_recursion)
      fprintf(fp, ",");
    else
      fprintf(fp, "[");
  
    symstkPrintNextTrieTerm(CTXTc fp, FALSE);
    symstkPrintNextTrieTerm(CTXTc fp, TRUE);
#endif
  } else {
    if(list_recursion)
      fprintf(fp, "uknown_symbol]");
    else
      fprintf(fp, "unknown_symbol");
  }
}

void printTriePath(CTXTdeclc FILE *fp, BTNptr pLeaf, xsbBool print_address)
{
  if(print_address)
    fprintf(fp, "Leaf Address: %x ", (unsigned int)pLeaf);
  
  BTNptr pRoot;
  
  SymbolStack_ResetTOS;
  SymbolStack_PushPathRootNodes(pLeaf, pRoot);
  
  fprintf(fp, "(");
  symstkPrintNextTrieTerm(CTXTc fp, FALSE);
  while(!SymbolStack_IsEmpty) {
    fprintf(fp, ",");
    symstkPrintNextTrieTerm(CTXTc fp, FALSE);
  }
  fprintf(fp, ")");
}

void printSubgoalTriePath(CTXTdeclc FILE *fp, BTNptr pLeaf, tab_ent_ptr tab_entry)
{
  fprintf(fp, "%s", string_val((Term)TabEnt_atom(tab_entry)));
  
  printTriePath(fp, pLeaf, NO);
}

static int variable_counter = 0;

static void
recursivePrintSubterm(FILE *fp, Term symbol, xsbBool list_recursion, PrintVarType var_type)
{
  XSB_Deref(symbol);
  
  if(IsIntTerm(symbol)) {
    if(list_recursion)
      fprintf(fp, "|" IntegerFormatString "]", int_val(symbol));
    else
      fprintf(fp, IntegerFormatString, int_val(symbol));
  } else if(IsVarTerm(symbol)) {
    if(list_recursion)
      fprintf(fp, "|");
    
    int var_index;
            
    if(IsStandardizedVariable(symbol)) {
      var_index = IndexOfStdVar(symbol);
    } else {
      Trail_Push(symbol);
      StandardizeVariable(symbol, variable_counter);
      var_index = variable_counter++;
    }
    
    fprintf(fp, "%s" IntegerFormatString, var_type == PRINT_ANSWER_VAR ? "ANSVAR" : "VAR", var_index);  
    
    if(list_recursion)
      fprintf(fp, "]");
  } else if(IsAtomTerm(symbol)) {
    char *string = string_val(symbol);
    
    if(list_recursion) {
      if(symbol == TermNil)
        fprintf(fp, "]");
      else
        fprintf(fp, "|%s]", string);
    }
    else
      fprintf(fp, "%s", string);
  } else if(IsApplTerm(symbol)) {
    Functor f = FunctorOfTerm(symbol);
    
    if(f == FunctorDouble) {
      Float dbl = FloatOfTerm(symbol);
      
      if(list_recursion)
        fprintf(fp, "|" FloatFormatString "]", dbl);
      else
        fprintf(fp, FloatFormatString, dbl);
    } else if(f == FunctorLongInt) {
      Int li = LongIntOfTerm(symbol);
      
      if(list_recursion)
        fprintf(fp, "|" LongIntFormatString "]", li);
      else
        fprintf(fp, LongIntFormatString, li);
    } else {
      int i;
      
      if(list_recursion)
        fprintf(fp, "|");
      
      fprintf(fp, "%s(", get_name(f));
      
      for(i = 1; i <= (int)get_arity(f); i++) {
        if(i > 1)
          fprintf(fp, ",");
        recursivePrintSubterm(fp, *(RepAppl(symbol) + i), FALSE, var_type);
      }
      
      fprintf(fp, ")");
      
      if(list_recursion)
        fprintf(fp, "]");
    }
  } else if(IsPairTerm(symbol)) {
    if(list_recursion)
      fprintf(fp, ",");
    else
      fprintf(fp, "[");
    
    recursivePrintSubterm(fp, *(RepPair(symbol)), FALSE, var_type);
    recursivePrintSubterm(fp, *(RepPair(symbol) + 1), TRUE, var_type);
  }
}

void printCalledSubgoal(FILE *fp, yamop *preg)
{
  int bindings = Trail_NumBindings;
  int i, arity = preg->u.Otapl.s;
  tab_ent_ptr tab_ent = preg->u.Otapl.te;
  
  variable_counter = 0;
  
  fprintf(fp, "SUBGOAL: %s(", string_val((Term)TabEnt_atom(tab_ent)));
  for(i = 1; i <= arity; ++i) {
    if(i > 1)
      fprintf(fp, ",");
    recursivePrintSubterm(fp, XREGS[i], FALSE, PRINT_VAR);
  }
  fprintf(fp, ")");
  
  Trail_Unwind(bindings);
}

#ifdef TABLING_CALL_SUBSUMPTION

static inline void fix_functor(Term t, CELL* placeholder);
static inline void fix_list(Term t, CELL* placeholder);
static inline void fix_rec(Term t, CELL* placeholder);

xsbBool are_identical_terms(Cell term1, Cell term2)
{
begin_are_identical_terms:
  XSB_Deref(term1);
  XSB_Deref(term2);
  
  if(term1 == term2)
    return TRUE;
  
  if(cell_tag(term1) != cell_tag(term2))
    return FALSE;
  
  if(cell_tag(term1) == XSB_STRUCT) {
    CPtr cptr1 = clref_val(term1);
    CPtr cptr2 = clref_val(term2);
    Psc psc1 = (Psc)*cptr1;
    int i;
    
    if(psc1 != (Psc)*cptr2)
      return FALSE;
    
    for(cptr1++, cptr2++, i = 0; i < (int)get_arity(psc1)-1; cptr1++, cptr2++, i++ )
      if(!are_identical_terms(*cptr1, *cptr2))
        return FALSE;
    term1 = *cptr1;
    term2 = *cptr2;
    goto begin_are_identical_terms;  
  }
  else if (cell_tag(term1) == XSB_LIST) {
    CPtr cptr1 = clrefp_val(term1);
    CPtr cptr2 = clrefp_val(term2);
    
    if(are_identical_terms(*cptr1, *cptr2)) {
      term1 = *(cptr1 + 1);
      term2 = *(cptr2 + 1);
      
      goto begin_are_identical_terms;
    } else return FALSE;
  }
#ifdef SUBSUMPTION_YAP
  else if(cell_tag(term1) == TAG_LONG_INT) {
    dprintf("identical long int\n");
    Int v1 = LongIntOfTerm(term1);
    Int v2 = LongIntOfTerm(term2);
    
    return v1 == v2;
  }
  else if(cell_tag(term1) == TAG_FLOAT) {
    dprintf("identical float term\n");
    
    Float dbl1 = FloatOfTerm(term1);
    Float dbl2 = FloatOfTerm(term2);
    
    return dbl1 == dbl2;
  }
#endif /* SUBSUMPTION_YAP */
  else return FALSE;
}

void printTrieNode(FILE *fp, BTNptr pTN)
{
  fprintf(fp, "Trie Node: Addr(%p) Symbol: ", pTN);
  printTrieSymbol(fp, BTN_Symbol(pTN));
}

void printTrieSymbol(FILE* fp, Cell symbol)
{
  switch(TrieSymbolType(symbol)) {
    case XSB_INT:
      fprintf(fp, IntegerFormatString, int_val(symbol));
      break;
    case XSB_FLOAT:
      fprintf(fp, "float");
      break;
    case XSB_STRING:
      fprintf(fp, "%s", string_val(symbol));
      break;
    case XSB_TrieVar:
      fprintf(fp, "VAR" IntegerFormatString, DecodeTrieVar(symbol));
      break;
    case XSB_STRUCT:
      {
        Psc psc;

        psc = DecodeTrieFunctor(symbol);
        fprintf(fp, "%s/%d", get_name(psc), get_arity(psc));
        break;
      }
    case XSB_LIST:
      fprintf(fp, "LIST");
      break;
    case TAG_LONG_INT:
      fprintf(fp, "LONG INT");
      break;
    default:
      fprintf(fp, "Unknown symbol (tag = %d)", cell_tag(symbol));
      break;
  }
}

void printAnswerTriePath(FILE *fp, ans_node_ptr leaf)
{
#ifdef FDEBUG
  SymbolStack_ResetTOS;
  SymbolStack_PushPathNodes(leaf);
  
  fprintf(fp, "{");
  symstkPrintNextTrieTerm(CTXTc fp, FALSE);
  while(!SymbolStack_IsEmpty) {
    fprintf(fp, ",");
    symstkPrintNextTrieTerm(CTXTc fp, FALSE);
  }
  fprintf(fp, "}");
#endif
}

void printSubterm(FILE *fp, Term term)
{
  int bindings = Trail_NumBindings;
  
  variable_counter = 0;
  recursivePrintSubterm(fp, term, FALSE, PRINT_VAR);
  
  Trail_Unwind(bindings);
}

void printAnswerTemplate(FILE *fp, CPtr ans_tmplt, int size)
{
#ifdef FDEBUG
  int bindings = Trail_NumBindings;
  
  fprintf(fp, "[");
  variable_counter = 0;
  
  int i;
  
  for(i = 0; i < size; ++i, ans_tmplt--) {
    if(i)
      fprintf(fp, ", ");
      
    recursivePrintSubterm(fp, (Term)ans_tmplt, FALSE, PRINT_VAR);
  }
  
  fprintf(fp, "]\n");
  
  Trail_Unwind(bindings);
#endif
}

void printSubstitutionFactor(FILE *fp, CELL* factor)
{
  int size = (int)*factor;
  
  fprintf(fp, "Substitution factor with size %d ", size);
  
  printAnswerTemplate(fp, factor + 1, size);
}

static void
recursive_construct_subgoal(CELL* trie_vars, CELL* placeholder)
{
  CELL symbol;
  
  SymbolStack_Pop(symbol);
  
  if(IsAtomOrIntTerm(symbol)) {
    dprintf("New constant\n");
    *placeholder = symbol;
  } else if(IsVarTerm(symbol)) {
    int index = DecodeTrieVar(symbol);
    
    if(IsNewTableVarTerm(symbol)) {
      *placeholder = (CELL)placeholder;
      *(trie_vars - index) = (CELL)placeholder;
      
      ++variable_counter;
    } else {
      *placeholder = *(trie_vars - index);
    }
    
    dprintf("New var\n");
    
  } else if(IsApplTerm(symbol)) {
    Functor f = DecodeTrieFunctor(symbol);

    if(f == FunctorDouble) {
      float_sg_node_ptr node;
      
      SymbolStack_PopOther(node, float_sg_node_ptr);
      
      *placeholder = MkFloatTerm(TrNode_float(node));
    } else if(f == FunctorLongInt) {
      long_sg_node_ptr node;
      
      SymbolStack_PopOther(node, long_sg_node_ptr);
      
      *placeholder = MkLongIntTerm(TrNode_long_int(node));
    } else {
      int i, arity = ArityOfFunctor(f);
      CELL *arguments;
      
      *placeholder = AbsAppl(H);
      
      dprintf("New functor\n");
      
      *H = (CELL)f;
      
      arguments = ++H;
      H += arity;

      for(i = 0; i < arity; ++i)
        recursive_construct_subgoal(trie_vars, arguments + i);
    }
  } else if(IsPairTerm(symbol)) {
    CELL *arguments = H;
    int i;
    
    *placeholder = AbsPair(H);
    
    dprintf("New pair\n");
    
    H += 2;
    
    for(i = 0; i < 2; ++i)
      recursive_construct_subgoal(trie_vars, arguments + i);
  } else {
    dprintf("BIG ERROR!!!\n");
  }
}

CELL* construct_subgoal_heap(BTNptr pLeaf, CPtr* var_pointer, int arity)
{
  CELL* orig_hreg = H;
  CELL* trie_vars = *var_pointer;
  int i;
  
  variable_counter = 0;
  
  TermStack_ResetTOS;
  SymbolStack_ResetTOS;
  SymbolStack_PushPathNodes(pLeaf);
  
  CELL *arguments = H;
  H += arity;
  
  for(i = 0; i < arity; ++i)
    recursive_construct_subgoal(trie_vars, arguments + i);
  for(i = arity - 1; i >= 0; --i)
    TermStack_Push(*(arguments + i))
  
  *var_pointer = trie_vars - variable_counter;
  **var_pointer = variable_counter;
  
  /* return original H register */
  return orig_hreg;
}

CPtr reconstruct_template_for_producer_no_args(SubProdSF subsumer, CPtr ans_tmplt) {
  int sizeAnsTmplt;
  Cell subterm, symbol;
  
  /*
   * Store the symbols along the path of the more general call.
   */
  SymbolStack_ResetTOS;
  SymbolStack_PushPath(subg_leaf_ptr(subsumer));
    
  /*
   * Create the answer template while we process.  Since we know we have a
   * more general subsuming call, we can greatly simplify the "matching"
   * process: we know we either have exact matches of non-variable symbols
   * or a variable paired with some subterm of the current call.
   */
  sizeAnsTmplt = 0;
  while(!TermStack_IsEmpty) {
    TermStack_Pop(subterm);
    XSB_Deref(subterm);
    SymbolStack_Pop(symbol);
    if(IsTrieVar(symbol) && IsNewTrieVar(symbol)) {
      *ans_tmplt-- = subterm;
      sizeAnsTmplt++;
    }
    else if(IsTrieFunctor(symbol))
      TermStack_PushFunctorArgs(subterm)
    else if(IsTrieList(symbol))
      TermStack_PushListArgs(subterm)
  }
  *ans_tmplt = makeint(sizeAnsTmplt);
  return ans_tmplt;
}

void
printTermStack(FILE *fp)
{
  int bindings = Trail_NumBindings;
  CELL* start = TermStack_Base;
  CELL* end = TermStack_Top;
  int total = TermStack_NumTerms - 1;
  
  variable_counter = 0;
  
  fprintf(fp, "(");
  for(--end; end >= start; --end, --total) {
    recursivePrintSubterm(fp, *end, FALSE, PRINT_VAR);
    if(total)
      fprintf(fp, ",");
  }
  fprintf(fp, ")");
  
  Trail_Unwind(bindings);
}

void printSubsumptiveAnswer(FILE *fp, CELL* vars)
{
  int total = (int)*vars;
  vars += total;
  int i = 0;

  Trail_ResetTOS;
  
  fprintf(fp, "    ");
  for(i = 0; i < total; ++i, --vars) {
    if(i)
      fprintf(fp, "    ");
    
    fprintf(fp, "VAR%d: ", i);
    recursivePrintSubterm(fp, *vars, FALSE, PRINT_ANSWER_VAR);
  }
  
  fprintf(fp, "\n");

  Trail_Unwind_All;
}

#ifdef SIZEOF_DOUBLE == 2*SIZEOF_INT_P
static inline Term
MakeFloatTerm(Float dbl)
{
  AT[0] = (CELL)FunctorDouble;
  *(Float *)(AT + 1) = dbl;
  AT[3] = EndSpecials;
  AT += 4;
  return AbsAppl(AT - 4);
}
#else
static inline Term
MakeFloatTerm(Float dbl)
{
  printf("AQUI\n");
  AT[0] = (CELL)FunctorDouble;
  *(Float *) (AT + 1) = dbl;
  AT[2] = EndSpecials;
  AT += 3;
  
  return AbsAppl(AT - 3);
}
#endif /* SIZEOF_DOUBLE == 2*SIZEOF_INT_P */

static inline Term
MakeLongIntTerm(Int i)
{
  AT[0] = (CELL)FunctorLongInt;
  AT[1] = (CELL)(i);
  AT[2] = EndSpecials;
  AT += 3;
  return AbsAppl(AT - 3);
}

static inline void
fix_functor(Term t, CELL* placeholder)
{
  Functor f = FunctorOfTerm(t);
  
  if(f == FunctorDouble) {
    *placeholder = MakeFloatTerm(FloatOfTerm(t));
  } else if(f == FunctorLongInt) {
    *placeholder = MakeLongIntTerm(LongIntOfTerm(t));
  } else {
    *placeholder = AbsAppl(AT);
    *AT++ = (CELL)f;
  
    CELL *arguments = AT;
    int i, arity = ArityOfFunctor(f);
     
    AT += arity;

    for(i = 1; i <= arity; ++i)
      fix_rec(Deref(*(RepAppl(t) + i)), arguments + i - 1);
  }
}

static inline void
fix_list(Term t, CELL* placeholder)
{
  *placeholder = AbsPair(AT);
  
  CELL* arguments = AT;
  
  AT += 2;
  
  fix_rec(Deref(*(RepPair(t))), arguments);
  fix_rec(Deref(*(RepPair(t) + 1)), arguments + 1);
}

static inline void
fix_rec(CELL val, CELL* placeholder)
{
  if(IsAtomOrIntTerm(val)) {
    *placeholder = val;
  } else if(IsVarTerm(val)) {
    if(IsStandardizedVariable(val)) {
      dprintf("Old variable\n");
      val = TrieVarBindings[IndexOfStdVar(val)];
      *placeholder = val;
    } else {
      dprintf("New variable\n");
      Trail_Push(val);
      StandardizeVariable(val, variable_counter);
      Trail_Push(&TrieVarBindings[variable_counter]);
      *placeholder = (CELL)placeholder;
      TrieVarBindings[variable_counter] = (CELL)placeholder;
      ++variable_counter;
    }
    
  } else if(IsApplTerm(val)) {
    fix_functor(val, placeholder);
  } else if(IsPairTerm(val)) {
    fix_list(val, placeholder);
  } else {
    printf("BAD TAG\n");
  }
}

int
fix_answer_template(CELL *ans_tmplt)
{
  int size = (int)*ans_tmplt++;
  int i;
  CELL *arguments = AT;
  
  Trail_ResetTOS;
  variable_counter = 0;
  
  AT += size;
  for(i = 0; i < size; ++i)
    fix_rec(Deref(*(ans_tmplt + i)), arguments + i);
  
  Trail_Unwind_All;

  return size;
}

#endif /* TABLING_CALL_SUBSUMPTION */
