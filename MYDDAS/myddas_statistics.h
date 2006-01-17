#ifdef MYDDAS_STATS
int 
myddas_util_get_conn_total_rows(MYDDAS_UTIL_CONNECTION);
void 
myddas_util_set_conn_total_rows(MYDDAS_UTIL_CONNECTION,int);

unsigned long
myddas_util_get_conn_total_time_DBServer(MYDDAS_UTIL_CONNECTION);
void 
myddas_util_set_conn_total_time_DBServer(MYDDAS_UTIL_CONNECTION,unsigned long);

unsigned long
myddas_util_get_conn_last_time_DBServer(MYDDAS_UTIL_CONNECTION);
void 
myddas_util_set_conn_last_time_DBServer(MYDDAS_UTIL_CONNECTION,unsigned long);
unsigned long
myddas_util_get_conn_total_time_transfering_from_DBServer(MYDDAS_UTIL_CONNECTION);
void 
myddas_util_set_conn_total_time_transfering_from_DBServer(MYDDAS_UTIL_CONNECTION,unsigned long);

unsigned long
myddas_util_get_conn_last_transfering_from_DBServer(MYDDAS_UTIL_CONNECTION);
void 
myddas_util_set_conn_last_transfering_from_DBServer(MYDDAS_UTIL_CONNECTION,unsigned long);
unsigned long
myddas_util_get_conn_total_transfering_from_DBServer(MYDDAS_UTIL_CONNECTION);
void 
myddas_util_set_conn_total_transfering_from_DBServer(MYDDAS_UTIL_CONNECTION,unsigned long);

unsigned long
myddas_util_get_conn_last_bytes_transfering_from_DBserver(MYDDAS_UTIL_CONNECTION);
void 
myddas_util_set_conn_last_bytes_transfering_from_DBserver(MYDDAS_UTIL_CONNECTION,unsigned long);
unsigned long
myddas_util_get_conn_total_bytes_transfering_from_DBserver(MYDDAS_UTIL_CONNECTION);
void 
myddas_util_set_conn_total_bytes_transfering_from_DBserver(MYDDAS_UTIL_CONNECTION,unsigned long);

unsigned long
myddas_util_get_conn_number_querys_made(MYDDAS_UTIL_CONNECTION);
void
myddas_util_set_conn_number_querys_made(MYDDAS_UTIL_CONNECTION, unsigned long);

unsigned long
myddas_util_get_total_db_row_function(void);
void
myddas_util_set_total_db_row_function(unsigned long);


unsigned long
myddas_current_time(void);

#endif /* MYDDAS_STATS */
