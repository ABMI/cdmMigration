# Details for connecting to the server:
dbms <- "postgresql"
user <- 'postgres' # ex) user
pw <- 'serV3RI7hOabml' # ex) password 
server <- '192.168.130.17' # ex) xxx.xxx.xxx.xxx
port <- '5433' # ex) 5432
cdmDatabase = 'evidnet' # ex) samplecdm
cdmSchema = 'cdmpv534_220228' # ex) dbo
# Details for embulk Settings:
maxThreads = 32
minOutputTasks = 16
outputServer = '192.168.130.17' # ex) xxx.xxx.xxx.xxx
outputUser = 'dspark' # ex) user
outputPw = 'qkrehdtn1!' # ex) password 
outputPort = '1433' # ex) 5432
outputCdmDatabase = 'CDMPv534'# ex) samplecdm
outputCdmSchema = 'dbo' # ex) cdm

connectionDetails <- DatabaseConnector::createConnectionDetails(dbms = dbms,
                                                                server = paste0(server,'/',cdmDatabase),
                                                                user = user,
                                                                password = pw,
                                                                port = port,
                                                                pathToDriver = getwd())
connection = DatabaseConnector::connect(connectionDetails = connectionDetails)

tableName <- DatabaseConnector::querySql(connection = connection,
                                         sql = paste0('SELECT table_name FROM information_schema.tables WHERE table_schema=',"'",cdmSchema,"'")
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


textFileVector <- readLines(file.path(getwd(),'sampleyaml_postgresTomssql.txt'))
textFile <- paste(textFileVector,collapse = '\n')


for(i in 1:length(paramList)){
  textFile <- gsub(pattern = paste0('<',names(paramList[i]),'>'),paramList[[i]],x = textFile)
}
for(i in 1:nrow(tableName)){
  write.table(gsub('<tableName>',tolower(tableName[i,]),textFile),file=paste0(getwd(),'/results/',tolower(tableName[i,]),'.yaml'),row.names = F,col.names = F,quote = F)
}



