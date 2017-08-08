var Proto = function (p) {

    var proto = p;

    this.CommonMessage = proto.loadProtoFile("/proto/CommonMessage.proto").build("CommonMessage");
    this.Shoot = this.CommonMessage.Shoot;

};