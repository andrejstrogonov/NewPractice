const crypto = require("crypto");
const grpc = require("@grpc/grpc-js");
const protoLoader = require("@grpc/proto-loader");

const API_KEY = process.env.NEURAL_API_KEY || "replace-me";
const PROTO_PATH = `${__dirname}/integrity.proto`;
const HEALTH_PROTO_PATH = `${__dirname}/health.proto`;

const packageDefinition = protoLoader.loadSync(PROTO_PATH, {
  keepCase: true,
  longs: String,
  enums: String,
  defaults: true,
  oneofs: true,
});

const integrityProto = grpc.loadPackageDefinition(packageDefinition).integrity;
const healthDefinition = protoLoader.loadSync(HEALTH_PROTO_PATH, {
  keepCase: true,
  longs: String,
  enums: String,
  defaults: true,
  oneofs: true,
});
const healthProto = grpc.loadPackageDefinition(healthDefinition).grpc.health.v1;

function extractToken(call) {
  const authValues = call.metadata.get("authorization");
  if (!authValues.length) {
    return null;
  }

  const value = String(authValues[0]).trim();
  return value.startsWith("Bearer ") ? value.slice(7) : value;
}

function checkAuth(call) {
  const token = extractToken(call);
  if (!token || token !== API_KEY) {
    return {
      code: grpc.status.PERMISSION_DENIED,
      message: "invalid api key",
    };
  }

  return null;
}

function sha256(input) {
  return crypto.createHash("sha256").update(input).digest("hex");
}

function checkIntegrity(call, callback) {
  const authError = checkAuth(call);
  if (authError) {
    callback(authError);
    return;
  }

  const { data, expected_hash, packet_id } = call.request;
  const calculatedHash = sha256(data || "");
  const isValid = calculatedHash === expected_hash;

  callback(null, {
    status: isValid ? "ok" : "error",
    message: isValid ? "packet integrity verified" : "packet integrity check failed",
    packet_id,
    calculated_hash: calculatedHash,
    is_valid: isValid,
    confidence: isValid ? 0.98 : 0.05,
    timestamp: new Date().toISOString(),
  });
}

function healthCheck(call, callback) {
  callback(null, { status: "SERVING" });
}

function main() {
  const server = new grpc.Server();
  server.addService(integrityProto.IntegrityService.service, {
    CheckIntegrity: checkIntegrity,
  });
  server.addService(healthProto.Health.service, {
    Check: healthCheck,
  });

  server.bindAsync("0.0.0.0:50051", grpc.ServerCredentials.createInsecure(), (error) => {
    if (error) {
      throw error;
    }

    console.log("Integrity gRPC server listening on 50051");
  });
}

main();
