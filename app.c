
typedef void request;
typedef void response;

typedef struct appdeps{
    const request *request;
    const char *route;
    const char *(*get_headder)(const request *request, const char *key);
    const char *(*get_query_param)(const request *request, const char *key);
    const unsigned char *(*read_body)(const request *request, long size);
    const response *(*send_any)(const unsigned char *content,long content_size,int status_code);
    const response *(*send_file)(const char *path,int status_code);






} appdeps;