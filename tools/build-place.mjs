import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const toolDir = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(toolDir, "..");
const read = (relativePath) => fs.readFileSync(path.join(root, relativePath), "utf8");
const xmlEscape = (value) => value.replaceAll("&", "&amp;").replaceAll("<", "&lt;").replaceAll(">", "&gt;").replaceAll('"', "&quot;");
const cdata = (value) => `<![CDATA[${value.replaceAll("]]>", "]]]]><![CDATA[>")}]]>`;

let referent = 0;
const nextReferent = () => `RBX${++referent}`;

const nameProperty = (name) => `<string name="Name">${xmlEscape(name)}</string>`;
const item = (className, name, properties = "", children = "") => `
<Item class="${className}" referent="${nextReferent()}">
  <Properties>${nameProperty(name)}${properties}</Properties>
  ${children}
</Item>`;

const scriptItem = (className, name, source) => item(
  className,
  name,
  `<ProtectedString name="Source">${cdata(source)}</ProtectedString><bool name="Disabled">false</bool>`,
);

const aircraftCatalog = scriptItem("ModuleScript", "AircraftCatalog", read("src/ReplicatedStorage/SkyDeck/AircraftCatalog.lua"));
const aircraftMeshManifest = scriptItem("ModuleScript", "AircraftMeshManifest", read("src/ReplicatedStorage/SkyDeck/AircraftMeshManifest.lua"));
const aircraftMeshValidator = scriptItem("ModuleScript", "AircraftMeshValidator", read("src/ReplicatedStorage/SkyDeck/AircraftMeshValidator.lua"));
const aircraftAnimationConfig = scriptItem("ModuleScript", "AircraftAnimationConfig", read("src/ReplicatedStorage/SkyDeck/AircraftAnimationConfig.lua"));
const aircraftVisualController = scriptItem("ModuleScript", "AircraftVisualController", read("src/ReplicatedStorage/SkyDeck/AircraftVisualController.lua"));
const aircraftSilhouetteConfig = scriptItem("ModuleScript", "AircraftSilhouetteConfig", read("src/ReplicatedStorage/SkyDeck/AircraftSilhouetteConfig.lua"));
const aircraftMaterialConfig = scriptItem("ModuleScript", "AircraftMaterialConfig", read("src/ReplicatedStorage/SkyDeck/AircraftMaterialConfig.lua"));
const aircraftLiveryConfig = scriptItem("ModuleScript", "AircraftLiveryConfig", read("src/ReplicatedStorage/SkyDeck/AircraftLiveryConfig.lua"));
const aircraftHandlingConfig = scriptItem("ModuleScript", "AircraftHandlingConfig", read("src/ReplicatedStorage/SkyDeck/AircraftHandlingConfig.lua"));
const aircraftEffectsConfig = scriptItem("ModuleScript", "AircraftEffectsConfig", read("src/ReplicatedStorage/SkyDeck/AircraftEffectsConfig.lua"));
const aircraftEffectsController = scriptItem("ModuleScript", "AircraftEffectsController", read("src/ReplicatedStorage/SkyDeck/AircraftEffectsController.lua"));
const aircraftLODController = scriptItem("ModuleScript", "AircraftLODController", read("src/ReplicatedStorage/SkyDeck/AircraftLODController.lua"));
const engineAudioConfig = scriptItem("ModuleScript", "EngineAudioConfig", read("src/ReplicatedStorage/SkyDeck/EngineAudioConfig.lua"));
const airportCatalog = scriptItem("ModuleScript", "AirportCatalog", read("src/ReplicatedStorage/SkyDeck/AirportCatalog.lua"));
const airportLayout = scriptItem("ModuleScript", "AirportLayout", read("src/ReplicatedStorage/SkyDeck/AirportLayout.lua"));
const airportSurfaces = scriptItem("ModuleScript", "AirportSurfaces", read("src/ReplicatedStorage/SkyDeck/AirportSurfaces.lua"));
const airportInteriors = scriptItem("ModuleScript", "AirportInteriors", read("src/ReplicatedStorage/SkyDeck/AirportInteriors.lua"));
const airportTerrain = scriptItem("ModuleScript", "AirportTerrain", read("src/ReplicatedStorage/SkyDeck/AirportTerrain.lua"));
const studioWorldBuilder = scriptItem("ModuleScript", "StudioWorldBuilder", read("src/ReplicatedStorage/SkyDeck/StudioWorldBuilder.lua"));
const sharedFolder = item("Folder", "SkyDeck", "", aircraftCatalog + aircraftMeshManifest + aircraftMeshValidator + aircraftAnimationConfig + aircraftVisualController + aircraftSilhouetteConfig + aircraftMaterialConfig + aircraftLiveryConfig + aircraftHandlingConfig + aircraftEffectsConfig + aircraftEffectsController + aircraftLODController + engineAudioConfig + airportCatalog + airportLayout + airportSurfaces + airportInteriors + airportTerrain + studioWorldBuilder);
const replicatedStorage = item("ReplicatedStorage", "ReplicatedStorage", "", sharedFolder);

const serverScript = scriptItem("Script", "SkyDeckServer", read("src/ServerScriptService/SkyDeckServer.server.lua"));
const serverScriptService = item("ServerScriptService", "ServerScriptService", "", serverScript);

const clientScript = scriptItem("LocalScript", "SkyDeckClient", read("src/StarterPlayer/StarterPlayerScripts/SkyDeckClient.client.lua"));
const starterPlayerScripts = item("StarterPlayerScripts", "StarterPlayerScripts", "", clientScript);
const starterPlayer = item("StarterPlayer", "StarterPlayer", "", starterPlayerScripts);

const workspace = item(
  "Workspace",
  "Workspace",
  `<bool name="StreamingEnabled">true</bool><float name="Gravity">196.2</float>`,
);

const lighting = item(
  "Lighting",
  "Lighting",
  `<float name="Brightness">2.2</float><float name="ClockTime">13.5</float><bool name="GlobalShadows">true</bool>`,
);

const xml = `<?xml version="1.0" encoding="utf-8"?>
<roblox version="4">
  <External>null</External>
  <External>nil</External>
  ${workspace}
  ${lighting}
  ${replicatedStorage}
  ${serverScriptService}
  ${starterPlayer}
</roblox>
`;

const requestedOutput = process.argv[2] || "Around-the-World.rbxlx";
if (path.basename(requestedOutput) !== requestedOutput || !requestedOutput.endsWith(".rbxlx")) {
  throw new Error("Output must be a .rbxlx filename inside the project folder");
}
const output = path.join(root, requestedOutput);
fs.writeFileSync(output, xml, "utf8");
process.stdout.write(`${output}\n`);
