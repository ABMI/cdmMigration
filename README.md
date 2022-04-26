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
cd cdmMigration
docker build -t embulk .
# docker image 확인 명령어
docker images
```

위 마지막 명령어로 embulk 이미지가 제대로 생겼다면 성공입니다.

#### 2. Embulk에 사용할 yaml 파일 세팅
CDM을 옮기기 위해 CDM 서버의 정보, 이관 될 CDM 서버의 정보를 input으로 넣고 yaml 파일을 output으로 얻는 R 스크립트를 실행합니다. 

- Rstudio Images 생성 및 실행
```bash
cd cdmMigration/embulk
docker build -t embulk_rstudio .
docker run -dit -p <미사용 port>:8787 -e PASSWORD=<password> -e ROOT=TRUE -v <cdmMigration 폴더 절대 경로>:/home/rstudio/data embulk_rstudio
ex) docker run -dit -p 8788:8787 -e PASSWORD=password -e ROOT=TRUE -v /home/administrator/git/cdmMigration:/home/rstudio/data rstudio
http://128.1.99.156:<미사용 port> 웹 브라우저 통해 접속 # id : rstudio, password는 위 컨테이너 설정 참고
컨테이너 내부에서 우측 하단 툴에서 data/Settings/createSettingFiles.R 실행
```

- Embulk yaml 파일 세팅
  - Database의 특정 Schema를 기반으로 모든 테이블을 이관하기 위해 R로 스크립트를 작성하였으며 경로는 아래와 같습니다.

##### createSettingFiles.R
```R
# setwd('') # createMigrationFiles.R 파일이 있는 경로 ex) ./cdmMigration/embulk/createEmbulkFiles/createSettingFiles.R
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
위 정보를 입력한 뒤 스크립트 전체를 실행해주면, 

- createEmbulkFiles/results/embulkFiles : embulk를 실행하기 위한 <cdm table name>.yaml 파일
- createEmbulkFiles/results/autoStart.sh : 위 yaml파일을 데몬으로 실행하고 log를 저장하기 위한 파일
- createEmbulkFiles/results/ddl : 이관 후 ddl을 설정하기 위한 파일
  
위 3개의 폴더에서 데이터 파일들이 생성됩니다.

#### 3. Embulk 컨테이너 생성 및 이관
```bash
# Embulk 컨테이너 생성
sudo docker run -it -v <results file Path>:/home/docker embulk
ex) sudo docker run -it -v /home/user/cdmMigration/embulk/createEmbulkFiles/results:/home/docker embulk
컨테이너 내부에서
cd /home/docker
chmod +x autoStart.sh
./autoStart.sh
```

## 2. Database Backup & Restore

같은 기종의 DB, 그리고 모든 권한이 존재한다면 아래 명령어로 이관하는 것이 더 빠르고 쉽습니다.
Database 별 Export, Import 명령어 모음입니다. 
  
  
### 2-1. Postgresql
Postgresql 서버의 터미널에서 수행
```bash
pg_dump --dbname=<dbname> -p <port> --username=<id> --format=t --blobs --verbose -f <cdmname>.dump
ex) pg_dump --dbname=samplecdm -p 5432 --username=user --format=t --blobs --verbose -f samplecdm.dump 
pg_restore -v -d <database_name> --username=<id> <dumpfile_name>.dump
ex) pg_restore -v -d samplecdm --username=user samplecdm.dump
```
  
### DDL 작업


## 4. CDM 마무리 작업
  
* Indexes, Constraints 작업
  - https://github.com/ohdsi/CommonDataModel/
  
* AChilles 작업
  - https://github.com/ohdsi/achilles
