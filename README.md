# cdmMigration

이기종 CDM 이관을 위해 OpenSource Software인 Docker, Embulk 기반으로 만든 repository 입니다.
Docker를 활용해 DB 이관을 위한 Embulk를 가상화하여 빌드하고 컨테이너를 만들어 CDM을 이관합니다. 

## 필요 Software
* Docker
* R (직접 설치 or Docker Container 세팅)

## 0. Docker Install

  - Window : https://docs.docker.com/desktop/windows/install/
  - Linux(18.04 LTS 기준) : 

```
# Docker 설치 준비
sudo apt update
sudo apt install apt-transport-https ca-certificates curl software-properties-common
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo apt-key add -
sudo add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu bionic stable"
sudo apt update
apt-cache policy docker-ce
# Docker 설치
sudo apt install docker-ce
# Docker 설치 확인
systemctl status docker
```


## 1. Embulk

### Embulk ?
- Embulk은 다양한 스토리지, 데이터베이스, NoSQL 및 클라우드 서비스 간의 데이터 전송을 돕는 병렬 벌크 데이터 로더입니다.  
- Embulk은 기능을 추가하기위한 플러그인을 지원합니다.  
- 플러그인을 공유하여 사용자 지정 스크립트를 읽고 유지 관리하고 재사용 할 수 있도록 유지할 수 있습니다.
- DSL(Domain Specific Language)를 활용, DB를 이관하기 위한 yaml 파일 포맷으로 세팅 후 embulk run 명령어로 이관 합니다. 

link : [embulk github](https://github.com/embulk/embulk)

### Purpose
병원 DB 서버의 CDM을 이관하는 용도로 사용합니다.

#### 1. Embulk Images 생성
Docker 기반으로 Embulk 이미지를 생성하기 위해 하는 작업입니다. 

- Embulk Images 생성
```bash
git clone https://github.com/ABMI/cdmMigration.git
cd cdmMigration/embulk
docker build -t embulk .
# docker image 확인 명령어
docker images
```
위 마지막 명령어로 embulk 이미지가 제대로 생겼다면 성공입니다.

#### 2. Embulk에 사용할 yaml 파일 세팅
CDM을 옮기기 위해 CDM 서버의 정보, 이관 될 CDM 서버의 정보를 input으로 넣고 yaml 파일을 output으로 얻는 R 스크립트를 실행합니다. 

- Embulk yaml 파일 세팅
  - Database의 특정 Schema를 기반으로 모든 테이블을 이관하기 위해 R로 스크립트를 작성하였으며 경로는 아래와 같습니다.
```
vim cdmMigration/createEmbulkFiles/createMigrationFiles.R
```
##### createMigrationFiles.R
```R
# setwd('') # createMigrationFiles.R 파일이 있는 경로 ex) ./cdmMigration/embulk/createEmbulkFiles/createMigrationFiles.R

# Details for connecting to the server:
# 이관 할 Server 정보
dbms <- "sql server"
user <- '' # ex) user
pw <- '' # ex) password 
server <- '' # ex) xxx.xxx.xxx.xxx
port <- '' # ex) 1433
cdmDatabase = '' # ex) samplecdm
cdmSchema = '' # ex) dbo
# Details for embulk Settings:
# 서버 Threads 사용량 
maxThreads = 32
minOutputTasks = 16
# 이관 될 Server 정보
outputServer = '' # ex) xxx.xxx.xxx.xxx
outputUser = '' # ex) user
outputPw = '' # ex) password 
outputPort = '' # ex) 5432
outputCdmDatabase = ''# ex) samplecdm
outputCdmSchema = '' # ex) cdm
```
위 정보를 입력한 뒤 스크립트 전체를 실행해주면, createEmbulkFiles/results 경로에 <tableName>.yaml 파일들이 생성 됩니다.

#### 3. Embulk 컨테이너 생성 및 이관
```bash
# Embulk 컨테이너 생성
sudo docker run -it -v <results file Path>:/home/docker embulk
ex) sudo docker run -it -v /home/user/cdmMigration/embulk/createEmbulkFiles/results:/home/docker embulk
# Embulk 이관 # 여러 터미널에서 동시에 진행하는 것을 추천
embulk run /home/docker/<tableName>.yaml
ex) embulk run /home/docker/person.yaml
```

## 2. Database Backup & Restore
Database 별 Export, Import 명령어 모음입니다. 
  
  
### 2-1. Postgresql
Postgresql 서버의 터미널에서 수행
```bash
pg_dump --dbname=<dbname> -p <port> --username=<id> --format=t --blobs --verbose -f <cdmname>.dump
ex) pg_dump --dbname=samplecdm -p 5432 --username=user --format=t --blobs --verbose -f samplecdm.dump 
pg_restore -v -d <database_name> --username=<id> <dumpfile_name>.dump
ex) pg_restore -v -d samplecdm --username=user samplecdm.dump
```
  
## 3. Database DDL Update
Embulk로 table을 이관할 때 DDL을 먼저 만들어 놓고 이관하는 방법과, 옮기고 DDL을 업데이트 하는 방법이 있습니다.
먼저 DDL을 만들어 놓고 이관하면 DBMS 데이터 타입 차이로 인해 데이터가 잘릴 수 있기 때문에 먼저 이관 뒤 DDL을 수정 합니다.

- ddl update 파일 세팅
- 이기종 DB에 맞게 CDM 테이블의 DDL을 변환하기 위해 R로 스크립트를 작성하였으며 경로는 아래와 같습니다.
```
vim cdmMigration/modifyDdl/mssqlToPostgresql/alterColumnDataType.R
```
##### alterColumnDataType.R
```R
# setwd('') # alterColumnDataType.R 파일이 있는 경로 ex) ./cdmMigration/modifyDdl/mssqlToPostgresql/alterColumnDataType.R
  
##input#################
cdmSchema = '' # CDM DB의 Schema 이름 ex) cdm
cdmVersion = '' # 이관한 CDM의 버전 ex) v5.3.1 / v5.3.0 (select * from cdm_source 에서 cdm version 확인)
########################
```
위 정보를 입력한 뒤 스크립트 전체를 실행해주면, console 창에 변환 쿼리가 생성 됩니다.
복사 붙여넣기 해서 Query 창에 실행하면 CDM DDL 변경이 완료 됩니다.

## 4. CDM 마무리 작업
  
* Indexes, Constraints 작업
  - https://github.com/ohdsi/CommonDataModel/
  
* AChilles 작업
  - https://github.com/ohdsi/achilles
