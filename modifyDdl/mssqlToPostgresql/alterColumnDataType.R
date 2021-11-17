setwd('D:\\git\\ABMI\\cdmMigration\\modifyDdl\\mssqlToPostgresql') # ./mssqlToPostgres

##input#################
cdmSchema = 'cdmpv533' # ex) cdm
cdmVersion = 'v5.3.1' # ex) v5.3.1 / v5.3.0
########################

# Postgresql CDM v5.3.1 # need divide craete table tableName \n ( 
if(cdmVersion == 'v5.3.1'){
  version = 'v5_3_1'
}else if(cdmVersion == 'v5.3.0'){
  version = 'v5_3'
}

ddl <- paste(readLines(file.path(getwd(),paste0('cdm_',version,'.txt'))),collapse = '\n')

start = unlist(gregexpr('CREATE',ddl))
end = unlist(gregexpr(';',ddl))

remove = c(',','')
for(i in 1:length(start)){
  ddlList = substr(ddl,start[i],end[i])
  tempList = unlist(lapply(ddlList, function(x) strsplit(x,'\n')))
  tempList = unlist(lapply(tempList, function(x) gsub('\t',' ',x)))
  tableName = unlist(lapply(tempList[1], function(x) gsub('CREATE TABLE ','',x)))
  tableName = unlist(lapply(tableName, function(x) gsub(' \\(','',x)))
  alterItemList = tempList[3:(length(tempList)-2)]
  alterItemList = strsplit(alterItemList,' ')
  alterItems = lapply(alterItemList, function(x) x[! x %in% remove])
  # ATLER TABLE 
  result = unlist(lapply(alterItems,function(x) 
    if(x[2] == 'DATE')
      paste0('ALTER TABLE ',cdmSchema,'.',tableName,' ALTER COLUMN ', x[1],' SET DATA TYPE date USING to_date(', x[1],",'YYYY-MM-DD')",';')
    else if(x[2] == "INTEGER"){
      paste0('ALTER TABLE ',cdmSchema,'.',tableName,' ALTER COLUMN ', x[1],' TYPE bigint USING (', x[1],'::bigint)',';')
    }else if(x[2] == "TIMESTAMP"){
      paste0('ALTER TABLE ',cdmSchema,'.',tableName,' ALTER COLUMN ', x[1],' TYPE TIMESTAMP USING ', x[1],'::timestamp without time zone',';')
    } else if(x[2] == "DATETIME2"){
      paste0('ALTER TABLE ',cdmSchema,'.',tableName,' ALTER COLUMN ', x[1],' TYPE TIMESTAMP USING ', x[1],'::timestamp without time zone',';')
    }
    else{
      paste0('ALTER TABLE ',cdmSchema,'.',tableName,' ALTER COLUMN ', x[1],' TYPE ', x[2],';')
    }
  ))
  # INTEGER to BIGINT
  result = lapply(result, function(x) gsub('INTEGER','BIGINT',x))
  lapply(result, function(x) cat(x,'\n'))
  # ATLER NULL, NOT NULL 
  # resultNull = unlist(lapply(alterItems,function(x) paste0('ALTER TABLE ',cdmSchema,'.',tableName,' ALTER COLUMN ', x[1],' SET ',paste(x[3:length(x)],collapse = ' '), ';')))
  # lapply(resultNull, function(x) cat(x,'\n'))
}

