class SchemataApiCpp {
public:
    virtual void apiInsert();
    virtual void apiSelect();
};

void runSchemataCpp(SchemataApiCpp *sac){
    sac->apiInsert();
    sac->apiSelect();
}
