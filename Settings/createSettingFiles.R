###############################################################
# Details for connecting to the server:
dbms <- "" # ex) 'postgresql' or 'sql server'
user <- '' # ex) user
pw <- '' # ex) password 
server <- '' # ex) xxx.xxx.xxx.xxx
port <- '' # ex) 5432 or 1433
cdmDatabase = '' # ex) database
cdmSchema = '' # ex) schema
# Details for embulk Settings:
maxThreads = 32
minOutputTasks = 16
outputDbms = '' # ex) 'postgresql' or 'sql server'
outputServer = '' # ex) xxx.xxx.xxx.xxx
outputUser = '' # ex) user
outputPw = '' # ex) password 
outputPort = '' # ex) 5432 or 1433
outputCdmDatabase = ''# ex) database
outputCdmSchema = '' # ex) schema
# cdm versions
cdmVersion = '' # ex) v5.3.1 or v5.3.0
###############################################################





if(dbms == "sql server"){
  sql = paste0('SELECT TABLE_NAME FROM ',cdmDatabase,'.INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA=',"'",cdmSchema,"'")
  inDbms = 'mssql'
}else if(dbms == 'postgresql'){
  server = paste0(server,'/',cdmDatabase)
  sql = paste0('SELECT table_name FROM information_schema.tables WHERE table_schema=',"'",cdmSchema,"'")
  inDbms = 'postgres'
}

if(outputDbms == 'sql server'){
  outDbms = 'mssql'
}else if(outputDbms == 'postgresql'){
  outDbms = 'postgres'
}

if(cdmVersion == 'v5.3.1'){
  version = 'v5_3_1'
}else if(cdmVersion == 'v5.3.0'){
  version = 'v5_3'
}

connectionDetails <- DatabaseConnector::createConnectionDetails(dbms = dbms,
                                                                server = server,
                                                                user = user,
                                                                password = pw,
                                                                port = port,
                                                                pathToDriver = getwd())

connection = DatabaseConnector::connect(connectionDetails = connectionDetails)

tableName <- DatabaseConnector::querySql(connection = connection,
                                         sql = sql)

paramList = list(
  'maxThreads'=maxThreads,
  'minOutputTasks'=minOutputTasks,
  'server'=server,
  'user'=user,
  'pw'=pw,
  'port'=port,
  'cdmDatabase'=cdmDatabase,
  'cdmSchema'=cdmSchema,
  'outputServer'=outputServer,
  'outputUser'=outputUser,
  'outputPw'=outputPw,
  'outputPort'=outputPort,
  'outputCdmDatabase'=outputCdmDatabase,
  'outputCdmSchema'=outputCdmSchema
)

textFileVector <- readLines(file.path(getwd(),'embulkYamlFile',paste0(inDbms,'To',outDbms,'.yaml')))
textFile <- paste(textFileVector,collapse = '\n')


for(i in 1:length(paramList)){
  textFile <- gsub(pattern = paste0('<',names(paramList[i]),'>'),paramList[[i]],x = textFile)
}
for(i in 1:nrow(tableName)){
  write.table(gsub('<tableName>',tolower(tableName[i,]),textFile),file=paste0(getwd(),'/results/embulkFiles/',tolower(tableName[i,]),'.yaml'),row.names = F,col.names = F,quote = F)
}

#Using Docker
data = c()
data = c(data,paste('mkdir /home/docker/logs'))
for(i in 1:nrow(tableName)){
  data = c(data,paste0('embulk run /home/docker/embulkFiles/',tableName[i,],'.yaml > /home/docker/',tableName[i,],'.txt &'))
}
write.table(data,file = paste0(getwd(),'/results/','autoStart.sh'),row.names = F,col.names = F,quote = F)

ddl <- paste(readLines(file.path(getwd(),paste0('/alterDdl/',outDbms,'_cdm_',version,'.txt'))),collapse = '\n')

start = unlist(gregexpr('CREATE',ddl))
end = unlist(gregexpr(';',ddl))

ddlQuery <- c()
postgresNullQuery <- c()
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
  if(outDbms == 'postgres'){
    result = unlist(lapply(alterItems,function(x)
      if(x[2] == 'DATE')
        paste0('ALTER TABLE ',outputCdmSchema,'.',tableName,' ALTER COLUMN ', x[1],' SET DATA TYPE date USING to_date(', x[1],",'YYYY-MM-DD')",';')
      else if(x[2] == "INTEGER"){
        paste0('ALTER TABLE ',outputCdmSchema,'.',tableName,' ALTER COLUMN ', x[1],' TYPE bigint USING (', x[1],'::bigint)',';')
      }else if(x[2] == "TIMESTAMP"){
        paste0('ALTER TABLE ',outputCdmSchema,'.',tableName,' ALTER COLUMN ', x[1],' TYPE TIMESTAMP USING ', x[1],'::timestamp without time zone',';')
      } else if(x[2] == "DATETIME2"){
        paste0('ALTER TABLE ',outputCdmSchema,'.',tableName,' ALTER COLUMN ', x[1],' TYPE TIMESTAMP USING ', x[1],'::timestamp without time zone',';')
      }
      else{
        paste0('ALTER TABLE ',outputCdmSchema,'.',tableName,' ALTER COLUMN ', x[1],' TYPE ', x[2],';')
      }
    ))
    
  }else if(outDbms == 'mssql'){
    result = unlist(lapply(alterItems,function(x)
      paste0('ALTER TABLE ',outputCdmSchema,'.',tableName,' ALTER COLUMN ', x[1], ' ', x[2], ' ', paste(x[3:length(x)],collapse = ' '),';')
    ))
    # remove comma
    result = lapply(result, function(x) gsub('NULL,','NULL',x))
  }
  # INTEGER to BIGINT
  result = lapply(result, function(x) gsub('INTEGER','BIGINT',x))
  ddlQuery <- c(ddlQuery,unlist(result))
  # ATLER NULL, NOT NULL
  resultNull = unlist(lapply(alterItems,function(x) paste0('ALTER TABLE ',outputCdmSchema,'.',tableName,' ALTER COLUMN ', x[1],' SET ',paste(x[3:length(x)],collapse = ' '), ';')))
  if(outDbms == "postgres"){
    postgresNullQuery <- c(postgresNullQuery,unlist(resultNull))
  }
}

if(outDbms == "postgres"){
  write.table(ddlQuery,file = paste0(getwd(),'/results/ddl/','ddl.txt'),row.names = F,col.names = F,quote = F)
  write.table(postgresNullQuery,file = paste0(getwd(),'/results/ddl/','ddlNull.txt'),row.names = F,col.names = F,quote = F)
}else if(outDbms == "mssql"){
  write.table(ddlQuery,file = paste0(getwd(),'/results/ddl/','ddl.txt'),row.names = F,col.names = F,quote = F)
}



