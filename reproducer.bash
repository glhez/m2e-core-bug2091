#!/bin/bash
set -euo pipefail
declare script_file=""
script_file="$(realpath "$0")"
declare script_dir="${script_file%/*}"

declare -r parent_pom_dir="${script_dir}/parent"
#declare -r parent_pom_file="${parent_pom_dir}/pom.xml"

declare -A deps_dir=()

aggregator() {
  local pom_file="${1}/pom.xml"
  local artifactId="${2}"
  shift 2

  local pom_dir="${pom_file%/*}"

  local rel_parent_pom_dir=""
  rel_parent_pom_dir=$(realpath --relative-to="${pom_dir}" --canonicalize-missing "${parent_pom_dir}")

  [[ ! -d "${pom_dir}" ]] && mkdir -p "${pom_dir}"

  for module; do
    case "${module}" in
      parent|aggr-*) : ;;
      *) deps_dir["${module}"]="${pom_dir}/${module}" ;;
    esac
  done

  {
    cat <<POM
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0"
         xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
         xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd"
>
  <modelVersion>4.0.0</modelVersion>

  <parent>
    <groupId>com.github.m2e-core.bug2091</groupId>
    <artifactId>parent</artifactId>
    <version>\${revision}</version>
    <relativePath>${rel_parent_pom_dir}</relativePath>
  </parent>

  <artifactId>${artifactId}</artifactId>
  <packaging>pom</packaging>
POM

    if [[ "$#" -gt 0 ]]; then
      cat <<POM
  <modules>
POM
    for module; do
      echo "    <module>${module}</module>"
    done
    cat <<POM
  </modules>
POM
    fi
    cat <<POM
</project>
POM
} > "${pom_file}"
}

module() {
  local packaging="${1}"
  local artifactId="${2}"
  shift 2

  local pom_dir="${deps_dir["${artifactId}"]}"
  local pom_file="${pom_dir}/pom.xml"

  local rel_parent_pom_dir=""
  rel_parent_pom_dir=$(realpath --relative-to="${pom_dir}" --canonicalize-missing "${parent_pom_dir}")

  mkdir -p "${pom_dir}"/src/{main,test}/{java,resources}

  if [[ "${packaging}" == war ]]; then
    mkdir -p "${pom_dir}/src/main/webapp/WEB-INF"

    cat <<WEB > "${pom_dir}/src/main/webapp/WEB-INF/web.xml"
<?xml version="1.0" encoding="UTF-8"?>
<web-app xmlns="https://jakarta.ee/xml/ns/jakartaee"
  xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
  xsi:schemaLocation="https://jakarta.ee/xml/ns/jakartaee
                      https://jakarta.ee/xml/ns/jakartaee/web-app_6_1.xsd"
  version="6.1"
  metadata-complete="true">
  <request-character-encoding>UTF-8</request-character-encoding>
</web-app>
WEB
  fi

  {
    cat <<POM
<?xml version="1.0" encoding="UTF-8"?>
<project xmlns="http://maven.apache.org/POM/4.0.0" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="http://maven.apache.org/POM/4.0.0 https://maven.apache.org/xsd/maven-4.0.0.xsd">
  <modelVersion>4.0.0</modelVersion>

  <parent>
    <groupId>com.github.m2e-core.bug2091</groupId>
    <artifactId>parent</artifactId>
    <version>\${revision}</version>
    <relativePath>${rel_parent_pom_dir}</relativePath>
  </parent>

  <artifactId>${artifactId}</artifactId>
POM
    if [[ "${packaging}" != jar ]]; then
      echo "  <packaging>${packaging}</packaging>"
    fi

    if [[ "$#" -gt 0 || "${packaging}" == war ]]; then
      cat <<POM

  <dependencies>
POM
      if [[ "${packaging}" == war ]]; then
        cat <<POM
    <dependency> <groupId>jakarta.servlet</groupId>             <artifactId>jakarta.servlet-api</artifactId>             <scope>provided</scope> </dependency>
    <dependency> <groupId>jakarta.servlet.jsp</groupId>         <artifactId>jakarta.servlet.jsp-api</artifactId>         <scope>provided</scope> </dependency>
    <dependency> <groupId>jakarta.el</groupId>                  <artifactId>jakarta.el-api</artifactId>                  <scope>provided</scope> </dependency>
    <dependency> <groupId>jakarta.websocket</groupId>           <artifactId>jakarta.websocket-api</artifactId>           <scope>provided</scope> </dependency>
POM
      fi

      for dependency; do
        echo "    <dependency> <groupId>com.github.m2e-core.bug2091</groupId> <artifactId>${dependency}</artifactId> </dependency>"
      done
      cat <<POM
  </dependencies>
POM
    fi
cat <<POM
</project>
POM
} > "${pom_file}"
}

aggregator .                                  aggr-root         parent aggr-{01,02,03,04,05,06}
aggregator 'aggr-01'                          aggr-01           dep-0{01,02,03,04,05}
aggregator 'aggr-02'                          aggr-02           dep-0{06,07,08,09,10}
aggregator 'aggr-03'                          aggr-03           dep-0{11,12,13,14,15}
aggregator 'aggr-04'                          aggr-04           aggr-04-{01,02}
aggregator 'aggr-04/aggr-04-01/'              aggr-04-01        aggr-04-01-{01,02}
aggregator 'aggr-04/aggr-04-02/'              aggr-04-02        aggr-04-02-{01,02}
aggregator 'aggr-04/aggr-04-01/aggr-04-01-01' aggr-04-01-01     dep-0{16,17,18,19,20}
aggregator 'aggr-04/aggr-04-01/aggr-04-01-02' aggr-04-01-02     dep-0{21,22,23,24,25}
aggregator 'aggr-04/aggr-04-02/aggr-04-02-01' aggr-04-02-01     dep-0{26,27,28,29,30}
aggregator 'aggr-04/aggr-04-02/aggr-04-02-02' aggr-04-02-02     dep-0{31,32,33,34,35}
aggregator 'aggr-05'                          aggr-05           dep-0{36,37,38,39,40}
aggregator 'aggr-06'                          aggr-06           dep-0{41,42,43,44,45}

#
module jar dep-001
module jar dep-002 dep-001
module jar dep-003 dep-002
module jar dep-004
module jar dep-005 dep-003 dep-004

module jar dep-006 dep-005
module jar dep-007 dep-004
module jar dep-008 dep-003
module jar dep-009
module jar dep-010

module jar dep-011 dep-009
module jar dep-012
module jar dep-013 dep-008 dep-019
module jar dep-014
module jar dep-015 dep-004

module jar dep-016
module jar dep-017 dep-016
module jar dep-018 dep-017
module jar dep-019 dep-018
module jar dep-020 dep-019

module jar dep-021 dep-020
module jar dep-022 dep-020
module jar dep-023 dep-020
module jar dep-024 dep-020
module jar dep-025 dep-020

module jar dep-026 dep-018 dep-022
module jar dep-027 dep-018 dep-022
module jar dep-028 dep-018 dep-022
module jar dep-029 dep-018 dep-022 dep-026
module jar dep-030 dep-018 dep-022 dep-028

module jar dep-031 dep-016 dep-021 dep-026
module jar dep-032 dep-017 dep-022 dep-027
module jar dep-033 dep-018 dep-023 dep-028
module jar dep-034 dep-019 dep-024 dep-029
module jar dep-035 dep-020 dep-025 dep-030

module jar dep-036 dep-016         dep-026 dep-031
module jar dep-037         dep-022         dep-032
module jar dep-038 dep-018         dep-028
module jar dep-039         dep-024         dep-034
module jar dep-040 dep-020         dep-030

module war dep-041 dep-001 dep-002 dep-003 dep-004 dep-005
module war dep-042 dep-006 dep-007 dep-008 dep-009 dep-010
module war dep-043 dep-011 dep-012 dep-013 dep-014 dep-015 dep-016 dep-017 dep-018 dep-019 dep-020
module war dep-044 dep-021 dep-022 dep-023 dep-024 dep-025 dep-036 dep-037 dep-038 dep-039 dep-040
module war dep-045 dep-026 dep-027 dep-028 dep-029 dep-030





