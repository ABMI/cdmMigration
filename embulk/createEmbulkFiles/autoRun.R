#if using Docker..
data = c()
data = c(data,paste('mkdir /home/docker/logs'))
for(i in 1:nrow(tableName)){
  data = c(data,paste0('embulk run ',tableName[i,],'.yaml > logs/',tableName[i,],'.txt &'))
}
write.table(data,file = paste0(getwd(),'/results/','autoStart.sh'),row.names = F,col.names = F,quote = F)