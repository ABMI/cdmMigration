# Details for connecting to the server:
dbms <- "sql server"
user <- '' # ex) user
pw <- '' # ex) password 
server <- '' # ex) xxx.xxx.xxx.xxx
port <- '' # ex) 1433
cdmDatabase = '' # ex) samplecdm
cdmSchema = '' # ex) dbo
# Details for embulk Settings:
maxThreads = 32
minOutputTasks = 16
outputServer = '' # ex) xxx.xxx.xxx.xxx
outputUser = '' # ex) user
outputPw = '' # ex) password 
outputPort = '' # ex) 5432
outputCdmDatabase = ''# ex) samplecdm
outputCdmSchema = '' # ex) cdm


connectionDetails <- DatabaseConnector::createConnectionDetails(dbms = dbms,
                                                                server = server,
                                                                user = user,
                                                                password = pw,
                                                                port = port,
                                                                pathToDriver = getwd())
connection = DatabaseConnector::connect(connectionDetails = connectionDetails)

tableName <- DatabaseConnector::querySql(connection = connection,
                                         sql = paste0('SELECT TABLE_NAME 
                                        FROM ',cdmDatabase,'.INFORMATION_SCHEMA.TABLES 
                                        WHERE TABLE_SCHEMA=',"'",cdmSchema,"'")
)

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


textFileVector <- readLines(file.path(getwd(),'sampleyaml_mssqlTopostgres.txt'))
textFile <- paste(textFileVector,collapse = '\n')


for(i in 1:length(paramList)){
  textFile <- gsub(pattern = paste0('<',names(paramList[i]),'>'),paramList[[i]],x = textFile)
}
for(i in 1:nrow(tableName)){
  write.table(gsub('<tableName>',tolower(tableName[i,]),textFile),file=paste0(getwd(),'/results/',tolower(tableName[i,]),'.yaml'),row.names = F,col.names = F,quote = F)
}



