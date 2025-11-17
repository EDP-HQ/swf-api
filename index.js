/**
 * API for ROLLER Apps  
 * - 
 * - EDP-HQ/roller-app
 * 
 */
var _expressPackage = require("express");
var _bodyParserPackage = require("body-parser");


const localdbConfig = require("./localdbConfig");

const database = require("./database");


const sPort = 3000;
//Initilize app with express web framework
var app = _expressPackage();
//To parse result in json format
app.use(_bodyParserPackage.json());
app.use(_expressPackage.json());


//Here we will enable CORS, so that we can access api on cross domain.
app.use(function (req, res, next) {
  res.header("Access-Control-Allow-Origin", "*");
  res.header("Access-Control-Allow-Methods", "GET,HEAD,OPTIONS,POST,PUT");
  res.header(
    "Access-Control-Allow-Headers",
    "Origin, X-Requested-With, contentType,Content-Type, Accept, Authorization"
  );
  next();
});

//Lets set up our local server now.
var server = app.listen(process.env.PORT || sPort, function () {
  var port = server.address().port;
  console.log("App now running on port", port);
});

function handleLog(code) {
  const currentDate = new Date();
  const formattedDate = currentDate.toLocaleString('en-US', {
    weekday: 'short',
    year: 'numeric',
    month: 'short',
    day: 'numeric',
    hour: 'numeric',
    minute: 'numeric',
    second: 'numeric',
    hour12: true
  });

  console.log(formattedDate + " : " + code);

}



// ########################################
// ###### API
// ########################################

function wIntro(req, res) {
  res.send("?? Kiswire ROLLER API now running on port " + sPort);
}

// Root route
app.get("/", wIntro);


//roller tracker


app.get("/roller/onoff", async function (req, res) {


  try {
  

    const storedProcedure = "sp_Roller_Run_ONOFF"; // Specify stored procedure

    // Call a function to execute the stored procedure without parameters
    await database.executeStoredProcedure(res, localdbConfig, storedProcedure, []); // Pass empty parameters array

  } catch (error) {
    console.error("Error processing the request:", error);
    if (!res.headersSent) {
      res.status(500).json({ error: "Internal Server Error" });
    }
  }
});


app.get("/roller/list", async function (req, res) {


  try {
  

    const storedProcedure = "sp_RollerTracker_SelectRoller"; // Specify stored procedure

    // Call a function to execute the stored procedure without parameters
    await database.executeStoredProcedure(res, localdbConfig, storedProcedure, []); // Pass empty parameters array

  } catch (error) {
    console.error("Error processing the request:", error);
    if (!res.headersSent) {
      res.status(500).json({ error: "Internal Server Error" });
    }
  }
});

// app.get("/roller/activelist", async (req, res) => {
//   try {
//     const storedProcedure = "sp_RollerTracker_SelectActive"; // add dbo.
//     await database.executeStoredProcedure(res, anepdbConfig, storedProcedure, []);
//   } catch (error) {
//     console.error("Error processing the request:", error);
//     res.status(500).json({ error: "Internal Server Error" });
//   }
// });

app.get("/roller/activelist", async function (req, res) {


  try {
  

    const storedProcedure = "sp_RollerTracker_ActiveRoller"; // Specify stored procedure

    // Call a function to execute the stored procedure without parameters
    await database.executeStoredProcedure(res, localdbConfig, storedProcedure, []); // Pass empty parameters array

  } catch (error) {
    console.error("Error processing the request:", error);
    if (!res.headersSent) {
      res.status(500).json({ error: "Internal Server Error" });
    }
  }
});



app.get("/roller/currentruntime", async function (req, res) {


  try {
  

    const storedProcedure = "sp_Roller_Curr_Runtime"; // Specify stored procedure

    // Call a function to execute the stored procedure without parameters
    await database.executeStoredProcedure(res, localdbConfig, storedProcedure, []); // Pass empty parameters array

  } catch (error) {
    console.error("Error processing the request:", error);
    if (!res.headersSent) {
      res.status(500).json({ error: "Internal Server Error" });
    }
  }
});


app.get("/roller/history", async function (req, res) {


  try {
  

    const storedProcedure = "sp_RollerTracker_SelectRollerInfoHistory"; // Specify stored procedure

    // Call a function to execute the stored procedure without parameters
    await database.executeStoredProcedure(res, localdbConfig, storedProcedure, []); // Pass empty parameters array

  } catch (error) {
    console.error("Error processing the request:", error);
    if (!res.headersSent) {
      res.status(500).json({ error: "Internal Server Error" });
    }
  }
});

app.post("/roller/updateruntimelimit", (req, res) => {
  try {
    const parameters = [
      { name: "RollerId", value: req.body.params.RollerID },
      { name: "RuntimeLimit", value: req.body.params.RuntimeLimit }
    ];
    const storedProcedure = "sp_Roller_Runtime_Limit_Update";
    database.executeStoredProcedure(res, localdbConfig, storedProcedure, parameters);
  } catch (error) {
    if (!res.headersSent) {
      res.status(500).json({ error: "Internal Server Error" });
    }
  }
});

app.post("/roller/batchupdateruntimelimit", (req, res) => {
  try {
    const { params = {} } = req.body || {};
    const { RollerID, RollerIDs, RuntimeLimit } = params;

    if (RuntimeLimit == null) {
      return res.status(400).json({ error: "RuntimeLimit is required" });
    }

    // If RollerIDs is provided (array or comma-separated), do batch update
    if (Array.isArray(RollerIDs) ? RollerIDs.length : typeof RollerIDs === "string") {
      // Normalize to comma-separated string
      const idsCsv = Array.isArray(RollerIDs)
        ? RollerIDs.map(s => String(s).trim()).filter(Boolean).join(",")
        : String(RollerIDs).split(",").map(s => s.trim()).filter(Boolean).join(",");

      if (!idsCsv) {
        return res.status(400).json({ error: "RollerIDs cannot be empty" });
      }

      const parameters = [
        { name: "RollerIds", value: idsCsv },          // matches @RollerIds in SP
        { name: "RuntimeLimit", value: RuntimeLimit }  // matches @RuntimeLimit in SP
      ];
      const storedProcedure = "sp_Roller_Runtime_Limit_BatchUpdate";
      return database.executeStoredProcedure(res, localdbConfig, storedProcedure, parameters);
    }

    // Otherwise use the single update SP with RollerID
    if (!RollerID) {
      return res.status(400).json({ error: "RollerID or RollerIDs is required" });
    }

    const parameters = [
      { name: "RollerId", value: RollerID },          // matches @RollerId in SP
      { name: "RuntimeLimit", value: RuntimeLimit }   // matches @RuntimeLimit in SP
    ];
    const storedProcedure = "sp_Roller_Runtime_Limit_Update";
    database.executeStoredProcedure(res, localdbConfig, storedProcedure, parameters);
  } catch (error) {
    if (!res.headersSent) {
      res.status(500).json({ error: "Internal Server Error" });
    }
  }
});

app.post("/roller/replace", (req, res) => {
  try {
    const { params = {} } = req.body || {};
    const { BinLocation, Company, Factory, RuntimeLimitDefault } = params;

    if (!BinLocation) {
      return res.status(400).json({ error: "BinLocation is required (e.g. 'ST0009_0001')" });
    }

    const parameters = [
      { name: "BinLocationCd", value: BinLocation },             // required
      { name: "Company", value: Company ?? null },               // optional fallback
      { name: "Factory", value: Factory ?? null },               // optional fallback
      { name: "RuntimeLimitDefault", value: RuntimeLimitDefault ?? null } // optional fallback
    ];

    const storedProcedure = "sp_RollerTracker_InsertReplacement";
    database.executeStoredProcedure(res, localdbConfig, storedProcedure, parameters);
  } catch (error) {
    if (!res.headersSent) {
      res.status(500).json({ error: "Internal Server Error" });
    }
  }
});


