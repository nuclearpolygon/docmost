.EXPORT_ALL_VARIABLES:
include .env

default: deploy

check_folders:
	@ssh ${SSH_URL} -qt "[ -d ${PROJECT_ROOT}/docmost ] && echo ${PROJECT_ROOT}/docmost exists || mkdir -p ${PROJECT_ROOT}/docmost"
	@ssh ${SSH_URL} -qt "[ -d ${LC_COMMON_ROOT}/nginx ] && echo ${LC_COMMON_ROOT}/nginx exists || mkdir -p ${LC_COMMON_ROOT}/nginx"

init_context:
	@echo "DOCKER CONTEXT IS ${DOCKER_CONTEXT_NAME}"
	@docker context ls | grep -E "${DOCKER_CONTEXT_NAME}[[:alnum:]_ *]+ssh://${SSH_URL}" || docker context create --docker "host=ssh://${SSH_URL}" --description="kitsu deploy context" "${DOCKER_CONTEXT_NAME}"
	@docker context show | grep "${DOCKER_CONTEXT_NAME}" || docker context use "${DOCKER_CONTEXT_NAME}"

reset_context:
	@docker context use default

build: reset_context
	@echo "build"
	@docker compose build --push

scp_files:
	@echo "scp files to server"
	@scp -r ./nginx/* ${SSH_URL}:${LC_COMMON_ROOT}/nginx
	@scp ./compose.nginx.docmost.yml ${SSH_URL}:${LC_COMMON_ROOT}

restart_nginx: scp_files
	@echo "restart nginx"
		@cat .env | ssh ${SSH_URL} -qt 'bash -c '\''\
		args=$$(find ${LC_COMMON_ROOT} -maxdepth 1  -name compose.nginx.*.yml -print0 | xargs -0 -I {} echo -f {}); \
		docker compose $$args down && docker compose $$args up -d'\'''

restart_nginx_deploy:
	@echo "restart nginx"
		@cat .env | ssh ${SSH_URL} -qt 'bash -c '\''\
		args=$$(find ${LC_COMMON_ROOT} -maxdepth 1  -name compose.nginx.*.yml -print0 | xargs -0 -I {} echo -f {}); \
		docker compose $$args down && docker compose $$args up -d'\'''

deploy: check_folders init_context scp_files
	@echo "deploy"
	@docker compose down && docker compose up -d --no-build --pull always
	@$(MAKE) restart_nginx_deploy
	@$(MAKE) reset_context

build_deploy: build deploy

generate_cert:
	@pushd ssl > /dev/null
	@[ -f ayon.key ] || openssl genrsa -out cg_docs.key 2048
	@openssl req -new -key cg_docs.key -out cg_docs.csr -config san.cnf
	@popd > /dev/null
