#!/bin/sh

if [ -z "$LOG_FILE" ]; then
	LOG_FILE=/var/www/html/output.log
fi
echo "Starting build script" > $LOG_FILE

if [ -z "$GITHUB_ENDPOINT" ]; then
    GITHUB_ENDPOINT="https://github.com/pndaproject"
fi  

if [ -z "$BRANCH" ]; then
    BRANCH="master"
fi 

cd /root

echo "Using GitHub endpoint: $GITHUB_ENDPOINT" >> $LOG_FILE
echo "Using branch: $BRANCH" >> $LOG_FILE

RELEASE_PATH="/var/www/html/$BRANCH"
#RELEASE_PATH="$PWD/$BRANCH"
echo "Set RELEASE_PATH: $RELEASE_PATH" >> $LOG_FILE

echo "Step 0: install required software" >> $LOG_FILE
JAVA_HOME="$PWD/jdk1.8.0_74"
if [ ! -d $JAVA_HOME ]; then
  echo "downloading jdk 8 from Oracle in $PWD" >> $LOG_FILE
  curl -b oraclelicense=accept-securebackup-cookie -L http://download.oracle.com/otn-pub/java/jdk/8u74-b02/jdk-8u74-linux-x64.tar.gz | tar xz --no-same-owner
  tar zcf jdk-8u74-linux-x64.tar.gz jdk1.8.0_74
  mkdir -p /var/www/html/components/java/jdk/8u74-b02
  cp jdk-8u74-linux-x64.tar.gz /var/www/html/components/java/jdk/8u74-b02/
else
  echo "	JAVA_HOME is already set as $JAVA_HOME" >> $LOG_FILE
fi
export PATH=$JAVA_HOME/bin:$PATH

apt-get install -y git nodejs npm gradle curl python-setuptools apt-transport-https
if [ ! -f /etc/apt/sources.list.d/sbt.list ]; then
	echo "	install sbt" >> $LOG_FILE
	echo "deb https://dl.bintray.com/sbt/debian /" | sudo tee -a /etc/apt/sources.list.d/sbt.list
	apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv 642AC823
	apt-get update
	apt-get install sbt
fi

if [ ! -d "/usr/share/apache-maven-3.2.5" ]; then
	echo "	install maven 3.2.5" >> $LOG_FILE
	wget https://archive.apache.org/dist/maven/maven-3/3.2.5/binaries/apache-maven-3.2.5-bin.tar.gz
	tar zxf apache-maven-3.2.5-bin.tar.gz
	mv apache-maven-3.2.5 /usr/share/
	rm /etc/alternatives/mvn
	ln -s /usr/share/apache-maven-3.2.5/bin/mvn /etc/alternatives/mvn
	ln -s /etc/alternatives/mvn /usr/bin
fi

if [ ! -f /usr/bin/node ]; then
	echo "	node link in /use/bin/node" >> $LOG_FILE
	ln -s /usr/bin/nodejs /usr/bin/node
fi

################################################################################################
PLATFORM_TESTING="$GITHUB_ENDPOINT/platform-testing.git"
echo "Step 1: cloning platform-testing $PLATFORM_TESTING in $PWD" >> $LOG_FILE
if [ ! -d "$	/platform-testing" ]; then
	echo "	cloning $BRANCH for platform-testing" >> $LOG_FILE
	git clone $PLATFORM_TESTING
	if [ ! -d "$PWD/platform-testing" ]; then
		echo "Error clonning platform-testing" >> $LOG_FILE
		exit 1
	fi
else
	echo "	getting $BRANCH for platform-testing" >> $LOG_FILE
fi
cd platform-testing
git checkout $BRANCH
git pull origin $BRANCH --tags
VERSION=$(git describe --abbrev=0 --tags | sed -e 's#.*/##')
if( [ -z "$VERSION" ] || [ "$VERSION" = "lis" ] ) then
	VERSION="latest"
fi
echo "VERSION=$VERSION" > VERSION
mvn versions:set -DnewVersion=$VERSION
mvn clean package
cd target
if [ ! -f platform-testing-cdh-$VERSION.tar.gz ]; then
	echo "	Error building platform-testing" >> $LOG_FILE
	exit 1
else
	echo "	Build done: platform-testing-cdh-$VERSION.tar.gz" >> $LOG_FILE
fi
sha512sum platform-testing-cdh-$VERSION.tar.gz > platform-testing-cdh-$VERSION.tar.gz.sha512.txt
sha512sum platform-testing-general-$VERSION.tar.gz > platform-testing-general-$VERSION.tar.gz.sha512.txt
mkdir -p "$RELEASE_PATH/packages/platform/releases/platform-testing"
mv platform-testing-cdh-$VERSION.tar.gz $RELEASE_PATH/packages/platform/releases/platform-testing/platform-testing-cdh-$VERSION.tar.gz
mv platform-testing-general-$VERSION.tar.gz $RELEASE_PATH/packages/platform/releases/platform-testing/platform-testing-general-$VERSION.tar.gz
mv platform-testing-cdh-$VERSION.tar.gz.sha512.txt $RELEASE_PATH/packages/platform/releases/platform-testing/platform-testing-cdh-$VERSION.tar.gz.sha512.txt
mv platform-testing-general-$VERSION.tar.gz.sha512.txt $RELEASE_PATH/packages/platform/releases/platform-testing/platform-testing-general-$VERSION.tar.gz.sha512.txt
cd ../..

################################################################################################
PLATFORM_DATA_MANAGEMENT="$GITHUB_ENDPOINT/platform-data-mgmnt.git" 
echo "Step 2: cloning platform-data-mgmnt $PLATFORM_DATA_MANAGEMENT in $PWD" >> $LOG_FILE
git clone $PLATFORM_DATA_MANAGEMENT
if [ ! -d "$PWD/platform-data-mgmnt" ]; then
	echo "	cloning $BRANCH for platform-data-mgmnt" >> $LOG_FILE
	git clone $PLATFORM_DATA_MANAGEMENT
	if [ ! -d "$PWD/platform-data-mgmnt" ]; then
		echo "Error clonning platform-data-mgmnt" >> $LOG_FILE
		exit 1
	fi
else
	echo "	getting $BRANCH for platform-data-mgmnt" >> $LOG_FILE
fi
cd platform-data-mgmnt
git checkout $BRANCH
git pull origin $BRANCH --tags
VERSION=$(git describe --abbrev=0 --tags | sed -e 's#.*/##')
if( [ -z "$VERSION" ] || [ "$VERSION" = "lis" ] ) then
	VERSION="latest"
fi
echo "VERSION=$VERSION" > VERSION
cd data-service
mvn versions:set -DnewVersion=$VERSION
mvn clean package
cd target
if [ ! -f data-service-$VERSION.tar.gz ]; then
	echo "	Error building data-service" >> $LOG_FILE
	exit 1
else
	echo "	Build done: data-service-$VERSION.tar.gz" >> $LOG_FILE
fi
sha512sum data-service-$VERSION.tar.gz > data-service-$VERSION.tar.gz.sha512.txt
mkdir -p "$RELEASE_PATH/packages/platform/releases/data-service"
mv data-service-$VERSION.tar.gz $RELEASE_PATH/packages/platform/releases/data-service/data-service-$VERSION.tar.gz
mv data-service-$VERSION.tar.gz.sha512.txt $RELEASE_PATH/packages/platform/releases/data-service/data-service-$VERSION.tar.gz.sha512.txt
cd ../..

cd hdfs-cleaner
mvn versions:set -DnewVersion=$VERSION
mvn clean package
cd target
if [ ! -f hdfs-cleaner-$VERSION.tar.gz ]; then
	echo "	Error building hdfs-cleaner" >> $LOG_FILE
	exit 1
else
	echo "	Build done: hdfs-cleaner-$VERSION.tar.gz" >> $LOG_FILE
fi
sha512sum hdfs-cleaner-$VERSION.tar.gz > hdfs-cleaner-$VERSION.tar.gz.sha512.txt
mkdir -p "$RELEASE_PATH/packages/platform/releases/hdfs-cleaner"
mv hdfs-cleaner-$VERSION.tar.gz $RELEASE_PATH/packages/platform/releases/hdfs-cleaner/hdfs-cleaner-$VERSION.tar.gz
mv hdfs-cleaner-$VERSION.tar.gz.sha512.txt $RELEASE_PATH/packages/platform/releases/hdfs-cleaner/hdfs-cleaner-$VERSION.tar.gz.sha512.txt
cd ../../..

################################################################################################
PLATFORM_DEPLOYMENT_MANAGER="$GITHUB_ENDPOINT/platform-deployment-manager.git"
echo "Step 3: cloning platform-deployment-manager $PLATFORM_DEPLOYMENT_MANAGER in $PWD" >> $LOG_FILE
if [ ! -d "$PWD/platform-deployment-manager" ]; then
	echo "	clonning $BRANCH for platform-deployment-manager" >> $LOG_FILE
	git clone $PLATFORM_DEPLOYMENT_MANAGER
	if [ ! -d "$PWD/platform-deployment-manager" ]; then
		echo "Error clonning platform-deployment-manager" >> $LOG_FILE
		exit 1
	fi
else
	echo "	getting $BRANCH for platform-deployment-manager" >> $LOG_FILE
fi
cd platform-deployment-manager
git checkout $BRANCH
git pull origin $BRANCH --tags

VERSION=$(git describe --abbrev=0 --tags | sed -e 's#.*/##')
if( [ -z "$VERSION" ] || [ "$VERSION" = "lis" ] ) then
	VERSION="latest"
fi
echo "VERSION=$VERSION" > VERSION
cd api
mvn versions:set -DnewVersion=$VERSION
mvn clean package
cd target
if [ ! -f deployment-manager-$VERSION.tar.gz ]; then
	echo "	Error building platform-deployment-manager" >> $LOG_FILE
	exit 1
else
	echo "	Build done: deployment-manager-$VERSION.tar.gz" >> $LOG_FILE
fi
sha512sum deployment-manager-$VERSION.tar.gz > deployment-manager-$VERSION.tar.gz.sha512.txt
mkdir -p "$RELEASE_PATH/packages/platform/releases/deployment-manager"
mv deployment-manager-$VERSION.tar.gz $RELEASE_PATH/packages/platform/releases/deployment-manager/deployment-manager-$VERSION.tar.gz
mv deployment-manager-$VERSION.tar.gz.sha512.txt $RELEASE_PATH/packages/platform/releases/deployment-manager/deployment-manager-$VERSION.tar.gz.sha512.txt
cd ../../..

################################################################################################
PLATFORM_PACKAGE_REPOSITORY="$GITHUB_ENDPOINT/platform-package-repository.git"
echo "Step 4: cloning platform-package-repository $PLATFORM_PACKAGE_REPOSITORY in $PWD" >> $LOG_FILE
if [ ! -d "$PWD/platform-package-repository" ]; then
	git clone $PLATFORM_PACKAGE_REPOSITORY
	if [ ! -d "$PWD/platform-package-repository" ]; then
		echo "Error clonning platform-package-repository" >> $LOG_FILE
		exit 1
	fi
else
	echo "	getting $BRANCH for platform-package-repository" >> $LOG_FILE
fi
cd platform-package-repository
git checkout $BRANCH
git pull origin $BRANCH --tags
VERSION=$(git describe --abbrev=0 --tags | sed -e 's#.*/##')
if( [ -z "$VERSION" ] || [ "$VERSION" = "lis" ] ) then
	VERSION="latest"
fi
echo "VERSION=$VERSION" > VERSION
cd api
mvn versions:set -DnewVersion=$VERSION
mvn clean package
cd target
if [ ! -f package-repository-$VERSION.tar.gz ]; then
	echo "	Error building platform-package-repository" >> $LOG_FILE
	exit 1
else
	echo "	Build done: package-repository-$VERSION.tar.gz" >> $LOG_FILE
fi
sha512sum package-repository-$VERSION.tar.gz > package-repository-$VERSION.tar.gz.sha512.txt
mkdir -p "$RELEASE_PATH/packages/platform/releases/package-repository"
mv package-repository-$VERSION.tar.gz $RELEASE_PATH/packages/platform/releases/package-repository/package-repository-$VERSION.tar.gz
mv package-repository-$VERSION.tar.gz.sha512.txt $RELEASE_PATH/packages/platform/releases/package-repository/package-repository-$VERSION.tar.gz.sha512.txt
cd ../../..

################################################################################################
PLATFORM_CONSOLE_FRONTEND="$GITHUB_ENDPOINT/platform-console-frontend.git" >> $LOG_FILE
echo "Step 5: cloning platform-console-frontend $PLATFORM_CONSOLE_FRONTEND in $PWD" >> $LOG_FILE
if [ ! -d "$PWD/platform-console-frontend" ]; then
	git clone $PLATFORM_CONSOLE_FRONTEND
	if [ ! -d "$PWD/platform-console-frontend" ]; then
		echo "Error clonning platform-console-frontend" >> $LOG_FILE
		exit 1
	fi
else
	echo "	getting $BRANCH for platform-console-frontend" >> $LOG_FILE
fi
cd platform-console-frontend
git checkout $BRANCH
git pull origin $BRANCH --tags
VERSION=$(git describe --abbrev=0 --tags | sed -e 's#.*/##')
if( [ -z "$VERSION" ] || [ "$VERSION" = "lis" ] ) then
	VERSION="latest"
fi
echo "VERSION=$VERSION" > VERSION
echo "Version  $VERSION" >> MANIFEST
echo "Git hash $GIT_COMMIT" > MANIFEST
cd console-frontend
npm install
npm install -g grunt
echo "{ \"name\": \"console-frontend\", \"version\": \"$VERSION\" }" > package-version.json
grunt package
if [ ! -f console-frontend-$VERSION.tar.gz ]; then
	echo "	Error building platform-console-frontend" >> $LOG_FILE
	exit 1
else
	echo "	Build done: console-frontend-$VERSION.tar.gz" >> $LOG_FILE
fi
sha512sum console-frontend-$VERSION.tar.gz > console-frontend-$VERSION.tar.gz.sha512.txt
mkdir -p "$RELEASE_PATH/packages/platform/releases/console/"
mv console-frontend-$VERSION.tar.gz $RELEASE_PATH/packages/platform/releases/console/console-frontend-$VERSION.tar.gz
mv console-frontend-$VERSION.tar.gz.sha512.txt $RELEASE_PATH/packages/platform/releases/console/console-frontend-$VERSION.tar.gz.sha512.txt
cd ../..

################################################################################################
PLATFORM_CONSOLE_BACKEND="$GITHUB_ENDPOINT/platform-console-backend.git" 
echo "Step 6: cloning platform-console-backend $PLATFORM_CONSOLE_BACKEND in $PWD" >> $LOG_FILE
if [ ! -d "$PWD/platform-console-backend" ]; then
	git clone $PLATFORM_CONSOLE_BACKEND
	if [ ! -d "$PWD/platform-console-backend" ]; then
		echo "Error clonning platform-console-backend" >> $LOG_FILE
		exit 1
	fi
else
	echo "	getting $BRANCH for platform-console-backend" >> $LOG_FILE
fi
cd platform-console-backend
git checkout $BRANCH
git pull origin $BRANCH --tags
VERSION=$(git describe --abbrev=0 --tags | sed -e 's#.*/##')
if( [ -z "$VERSION" ] || [ "$VERSION" = "lis" ] ) then
	VERSION="latest"
fi
echo "VERSION=$VERSION" > VERSION
cp -R console-backend-utils console-backend-data-logger/
echo "Version  $VERSION" >> console-backend-data-logger/MANIFEST
cd console-backend-data-logger
npm install
echo "{ \"name\": \"console-backend-data-logger\", \"version\": \"$VERSION\" }" > package-version.json
grunt --verbose package
if [ ! -f console-backend-data-logger-$VERSION.tar.gz ]; then
	echo "	Error building platform-console-backend-data-logger" >> $LOG_FILE
	exit 1
else
	echo "	Build done: console-backend-data-logger-$VERSION.tar.gz" >> $LOG_FILE
fi
sha512sum console-backend-data-logger-$VERSION.tar.gz > console-backend-data-logger-$VERSION.tar.gz.sha512.txt
mkdir -p "$RELEASE_PATH/packages/platform/releases/console"
mv console-backend-data-logger-$VERSION.tar.gz $RELEASE_PATH/packages/platform/releases/console/console-backend-data-logger-$VERSION.tar.gz
mv console-backend-data-logger-$VERSION.tar.gz.sha512.txt $RELEASE_PATH/packages/platform/releases/console/console-backend-data-logger-$VERSION.tar.gz.sha512.txt
cd ..
cp -R console-backend-utils console-backend-data-manager/
mkdir -p console-backend-data-manager/conf
echo "Version  $VERSION" >> console-backend-data-manager/MANIFEST
cd console-backend-data-manager
npm install
echo "{ \"name\": \"console-backend-data-manager\", \"version\": \"$VERSION\" }" > package-version.json
grunt package --verbose
if [ ! -f console-backend-data-manager-$VERSION.tar.gz ]; then
	echo "	Error building platform-console-backend-data-manager" >> $LOG_FILE
	exit 1
else
	echo "	Build done: console-backend-data-manager-$VERSION.tar.gz" >> $LOG_FILE
fi
sha512sum console-backend-data-manager-$VERSION.tar.gz > console-backend-data-manager-$VERSION.tar.gz.sha512.txt
mv console-backend-data-manager-$VERSION.tar.gz $RELEASE_PATH/packages/platform/releases/console/console-backend-data-manager-$VERSION.tar.gz
mv console-backend-data-manager-$VERSION.tar.gz.sha512.txt $RELEASE_PATH/packages/platform/releases/console/console-backend-data-manager-$VERSION.tar.gz.sha512.txt
cd ../..

################################################################################################
PLATFORM_LIBRARIES="$GITHUB_ENDPOINT/platform-libraries.git" 
echo "Step 7: cloning platform-libraries $PLATFORM_LIBRARIES in $PWD" >> $LOG_FILE
if [ ! -d "$PWD/platform-libraries" ]; then
	git clone $PLATFORM_LIBRARIES
	if [ ! -d "$PWD/platform-libraries" ]; then
		echo "Error clonning platform-libraries" >> $LOG_FILE
		exit 1
	fi
else
	echo "	getting $BRANCH for platform-libraries" >> $LOG_FILE
fi
cd platform-libraries
git checkout $BRANCH
git pull origin $BRANCH --tags
VERSION=$(git describe --abbrev=0 --tags | sed -e 's#.*/##')
if( [ -z "$VERSION" ] || [ "$VERSION" = "lis" ] ) then
	VERSION="latest"
fi
export VERSION=$VERSION
echo "VERSION=$VERSION" > VERSION
SPARK_HOME="$PWD/../spark-1.5.0-bin-hadoop2.6"
SPARK_VERSION='1.5.0'
HADOOP_VERSION='2.6'
if [ ! -d $SPARK_HOME ]; then
  cd ..
  echo "	downloading spark 1.5.0 in $PWD" >> $LOG_FILE
  curl http://archive.apache.org/dist/spark/spark-$SPARK_VERSION/spark-$SPARK_VERSION-bin-hadoop$HADOOP_VERSION.tgz --output ./spark-$SPARK_VERSION-bin-hadoop$HADOOP_VERSION.tgz
  tar -xvzf spark-$SPARK_VERSION-bin-hadoop$HADOOP_VERSION.tgz
  cd platform-libraries
else
  echo "	SPARK_HOME is already set as $SPARK_HOME" >> $LOG_FILE
fi
python setup.py bdist_egg
cd dist
if [ ! -f platformlibs-$VERSION-py2.7.egg ]; then
	echo "	Error building platform-libraries" >> $LOG_FILE
	exit 1
else
	echo "	Build done: platformlibs-$VERSION-py2.7.egg" >> $LOG_FILE
fi
sha512sum platformlibs-$VERSION-py2.7.egg > platformlibs-$VERSION-py2.7.egg.sha512.txt
mkdir -p "$RELEASE_PATH/packages/platform/releases/platform-libraries"
mv platformlibs-$VERSION-py2.7.egg $RELEASE_PATH/packages/platform/releases/platform-libraries/platformlibs-$VERSION-py2.7.egg
mv platformlibs-$VERSION-py2.7.egg.sha512.txt $RELEASE_PATH/packages/platform/releases/platform-libraries/platformlibs-$VERSION-py2.7.egg.sha512.txt
cd ../..

################################################################################################
PLATFORM_GOBBLIN="$GITHUB_ENDPOINT/gobblin.git" 
echo "Step 8: cloning gobblin $PLATFORM_GOBBLIN in $PWD" >> $LOG_FILE
if [ ! -d "$PWD/gobblin" ]; then
	git clone $PLATFORM_GOBBLIN
	if [ ! -d "$PWD/gobblin" ]; then
		echo "Error clonning gobblin" >> $LOG_FILE
		exit 1
	fi
else
	echo "	getting $BRANCH for gobblin" >> $LOG_FILE
fi
cd gobblin
git checkout PNDA
git pull origin PNDA
VERSION=$(git describe --abbrev=0 --tags | sed -e 's#.*/##')
if( [ -z "$VERSION" ] || [ "$VERSION" = "lis" ] ) then
	VERSION="latest"
fi
echo "VERSION=$VERSION" > VERSION
HADOOP_VERSION=2.6.0-cdh5.4.9

./gradlew build -Pversion=${VERSION} -PuseHadoop2 -PhadoopVersion=${HADOOP_VERSION}
PNDA_RELEASE_NAME=gobblin-distribution-${VERSION}.tar.gz
if [ ! -f $PNDA_RELEASE_NAME ]; then
	echo "	Error building gobblin" >> $LOG_FILE
	exit 1
else
	echo "	Build done: $PNDA_RELEASE_NAME" >> $LOG_FILE
fi
sha512sum ${PNDA_RELEASE_NAME} > ${PNDA_RELEASE_NAME}.sha512.txt
mkdir -p "$RELEASE_PATH/packages/platform/releases/gobblin"
cp ${PNDA_RELEASE_NAME} $RELEASE_PATH/packages/platform/releases/gobblin/${PNDA_RELEASE_NAME}
cp  ${PNDA_RELEASE_NAME}.sha512.txt $RELEASE_PATH/packages/platform/releases/gobblin/${PNDA_RELEASE_NAME}.sha512.txt
cd ..

################################################################################################
echo "Step 9: Building Kafka manager" >> $LOG_FILE
VERSION=1.3.1.6
KAFKA_MANAGER="$PWD/kafka-manager-${VERSION}"
if [ ! -d $KAFKA_MANAGER ]; then
  echo "downloading kafka manager $VERSION in $PWD" >> $LOG_FILE
  wget https://github.com/yahoo/kafka-manager/archive/${VERSION}.tar.gz
  tar xzf ${VERSION}.tar.gz
else
  echo "	KAFKA_MANAGER is already set as $KAFKA_MANAGER" >> $LOG_FILE
fi
if [ ! -f .sbt/0.13/local.sbt ]; then
	mkdir -p .sbt/0.13
	echo 'scalacOptions ++= Seq("-Xmax-classfile-name","100")' >> .sbt/0.13/local.sbt
fi
cd $KAFKA_MANAGER
sbt clean dist
cd target/universal/
if [ ! -f kafka-manager-${VERSION}.zip ]; then
	echo "	Error building kafka manager" >> $LOG_FILE
	exit 1
else
	echo "	Build done: kafka-manager-${VERSION}.zip" >> $LOG_FILE
fi
sha512sum kafka-manager-${VERSION}.zip > kafka-manager-${VERSION}.zip.sha512.txt
mkdir -p "$RELEASE_PATH/packages/platform/releases/kafka-manager"
mv kafka-manager-${VERSION}.zip $RELEASE_PATH/packages/platform/releases/kafka-manager/kafka-manager-${VERSION}.zip
mv kafka-manager-${VERSION}.zip.sha512.txt $RELEASE_PATH/packages/platform/releases/kafka-manager/kafka-manager-${VERSION}.zip.sha512.txt
cd ../../..


