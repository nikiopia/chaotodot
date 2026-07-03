// ----- CONTROL VARIABLES ----- //

float ZERO_TOLERANCE = 0.0001;
int[] zeroVector = new int[3];

// Camera position (deg / XYZ)
int cameraPosition_lat, cameraPosition_lon;
float cameraPosition_lat_float = 0;
float cameraPosition_lon_float = 0;
float[] cameraPosition_xyz = new float[3];
int[] cameraOffset_xyz = new int[3];
int cameraRadius = 5;
int dimensionUnlock = -1;

// Camera orientation (deg)
int cameraOrientation_lat, cameraOrientation_lon;
boolean cameraMoved = true;

// Camera POV i, j, k
float[] cameraPOV_i = new float[3];
float[] cameraPOV_j = new float[3];
float[] cameraPOV_k = new float[3];

// Change of Basis Matrix (COBM)
float[][] COBM = new float[3][3];
float determinant;
float a, b, c, d, e, f, g, h, i;

// Rendering to screen
float relativeX, relativeY, relativeZ;
int screenX, screenY;

// Point database
float[] points_x = new float[1008];
float[] points_y = new float[1008];
float[] points_z = new float[1008];
int NUMBER_OF_POINTS = 1008;
float MAX_RADIUS = 200;

// Animation time value
int time = 0;

// Last mouse location
int lastMouseX, lastMouseY;

// Perspective sizing
float distanceToCamera;

// GUI / Simulation controls
boolean HUD_On = false;
boolean runSimulation = true;
boolean resetSimulation = true;

// Point updating
float timeStep = 0.01;
float x, y, z;

// ----- HELPER FUNCTIONS ----- //

void LatLon_toXYZ(int lat, int lon, int radius, int cameraOffset_xyz[], float[] xyz)
{
  xyz[0] = cameraOffset_xyz[0] + radius * cos(radians(lat)) * cos(radians(lon));
  xyz[1] = cameraOffset_xyz[1] + radius * cos(radians(lat)) * sin(radians(lon));
  xyz[2] = cameraOffset_xyz[2] + radius * sin(radians(lat));
}

String truncate(float value)
{
  return str(round(value * 100) / 100.0);
}

void setupStarterBox()
{
  int currentPoint = NUMBER_OF_POINTS - 8;
  for (int x = cameraOffset_xyz[0] - 1; x <= cameraOffset_xyz[0] + 1; x += 2)
  {
    for (int y = cameraOffset_xyz[1] - 1; y <= cameraOffset_xyz[1] + 1; y += 2)
    {
      for (int z = cameraOffset_xyz[2] - 1; z <= cameraOffset_xyz[2] + 1; z += 2)
      {
        if (currentPoint >= NUMBER_OF_POINTS)
        {
          println("Error: Malformed starter box setup");
          return;
        }
        
        points_x[currentPoint] = float(x);
        points_y[currentPoint] = float(y);
        points_z[currentPoint] = float(z);
        currentPoint++;
      }
    }
  }
}

// ----- CORE FUNCTIONS ----- //

void mousePressed()
{
  if (mouseX >= (width - 50))
  {
    if (mouseY <= 50)
    {
      HUD_On = !HUD_On;
      return;
    }
    
    if (mouseY <= 100)
    {
      runSimulation = !runSimulation;
      return;
    }
    
    if (mouseY <= 150)
    {
      resetSimulation = true;
      return;
    }
    
    if (mouseY <= 250)
    {
      dimensionUnlock = dimensionUnlock == -1 ? 0 : -1;
      return;
    }
    
    if (mouseY <= 300)
    {
      dimensionUnlock = dimensionUnlock == -1 ? 1 : -1;
      return;
    }
    
    if (mouseY <= 350)
    {
      dimensionUnlock = dimensionUnlock == -1 ? 2 : -1;
      return;
    }
  }
}

void mouseDragged()
{
  cameraPosition_lat_float += (mouseY - pmouseY) * 0.1;
  cameraPosition_lon_float -= (mouseX - pmouseX) * 0.2;
  
  cameraPosition_lat = (round(cameraPosition_lat_float) + 360) % 360;
  cameraPosition_lon = (round(cameraPosition_lon_float) + 360) % 360;
  
  cameraMoved = true;
}

void mouseWheel(MouseEvent e)
{
  if (e.getCount() > 0)
  {
    switch (dimensionUnlock)
    {
      case 0:
        cameraOffset_xyz[0] += 1;
        break;
      case 1:
        cameraOffset_xyz[1] += 1;
        break;
      case 2:
        cameraOffset_xyz[2] += 1;
        break;
      default:
        cameraRadius++;
        break;
    }
  }
  else
  {
    switch (dimensionUnlock)
    {
      case 0:
        cameraOffset_xyz[0] -= 1;
        break;
      case 1:
        cameraOffset_xyz[1] -= 1;
        break;
      case 2:
        cameraOffset_xyz[2] -= 1;
        break;
      default:
        cameraRadius--;
        cameraRadius = cameraRadius < 0 ? 0 : cameraRadius;
        break;
    }
  }
  
  if (dimensionUnlock != -1)
  {
    setupStarterBox();
  }
  
  cameraMoved = true;
}

void setup()
{
  // Vector / Matrix initializations
  for (int i = 0; i < 3; i++)
  {
    // 1D vectors (Dimension 3)
    cameraPosition_xyz[i] = float(0);
    cameraOffset_xyz[i] = 0;
    zeroVector[i] = 0;
    
    for (int j = 0; j < 3; j++)
    {
      // 2D matrix (Dimension 3x3)
      COBM[i][j] = float(0);
    }
  }
  
  // Setup starter box
  setupStarterBox();
  
  // Screen configuration
  size(700, 600);
  frameRate(30);
  fill(0, 255, 0);
  stroke(0, 255, 0);
  pixelDensity(1);
  
  // Begin with empty background
  background(0);
}

void draw()
{
  background(0);
  
  // Reset simulation if requested
  if (resetSimulation)
  {
    resetSimulation = false;
    
    for (int i = 0; i < NUMBER_OF_POINTS - 8; i++)
    {
      points_x[i] = float(cameraOffset_xyz[0]) + random(-1, 1);
      points_y[i] = float(cameraOffset_xyz[1]) + random(-1, 1);
      points_z[i] = float(cameraOffset_xyz[2]) + random(-1, 1);
    }
  }
  
  // Only recompute this graphics stuff if its absolutely necessary
  if (cameraMoved)
  {
    cameraMoved = false;
    
    // Camera position
    LatLon_toXYZ(cameraPosition_lat, cameraPosition_lon, cameraRadius, cameraOffset_xyz, cameraPosition_xyz);
    
    // Camera orientation
    cameraOrientation_lat = -cameraPosition_lat;
    cameraOrientation_lon = (cameraPosition_lon + 180 + 360) % 360;
    
    // Camera POV directions
    LatLon_toXYZ(0, cameraOrientation_lon - 90, 1, zeroVector, cameraPOV_i);
    LatLon_toXYZ(cameraOrientation_lat, cameraOrientation_lon, 1, zeroVector, cameraPOV_j);
    LatLon_toXYZ(cameraOrientation_lat + 90, cameraOrientation_lon, 1, zeroVector, cameraPOV_k);
    
    // Change of basis matrix -- setting up matrix for easy formula use
    a = cameraPOV_i[0];
    b = cameraPOV_j[0];
    c = cameraPOV_k[0];
    d = cameraPOV_i[1];
    e = cameraPOV_j[1];
    f = cameraPOV_k[1];
    g = cameraPOV_i[2];
    h = cameraPOV_j[2];
    i = cameraPOV_k[2];
    determinant = a * (e * i - f * h) - b * (d * i - f * g) + c * (d * h - e * g);
    if (abs(determinant) <= ZERO_TOLERANCE)
    {
      println("Determinant <= ZERO_TOLERANCE");
      return;
    }
    
    // Use the adjoint + determinant method for 3x3 matrix inverse
    COBM[0][0] = (e * i - f * h) / determinant;
    COBM[0][1] = -(b * i - c * h) / determinant;
    COBM[0][2] = (b * f - c * e) / determinant;
    COBM[1][0] = -(d * i - f * g) / determinant;
    COBM[1][1] = (a * i - c * g) / determinant;
    COBM[1][2] = -(a * f - c * d) / determinant;
    COBM[2][0] = (d * h - e * g) / determinant;
    COBM[2][1] = -(a * h - b * g) / determinant;
    COBM[2][2] = (a * e - b * d) / determinant;
  }
  
  // Point display / Render pipeline
  for (int index = 0; index < NUMBER_OF_POINTS; index++)
  { 
    // Create static copy of current point location so original copy can be updated
    x = points_x[index];
    y = points_y[index];
    z = points_z[index];
    
    if (runSimulation && index < NUMBER_OF_POINTS - 8)
    {
      if (dist(points_x[index], points_y[index], points_z[index], cameraOffset_xyz[0], cameraOffset_xyz[1], cameraOffset_xyz[2]) < MAX_RADIUS)
      {
        // Update point location according to formulas
        
        // Halvorsen Attractor
        points_x[index] += timeStep * (-1.89 * x - 4 * y - 4 * z - y * y);
        points_y[index] += timeStep * (-1.89 * y - 4 * z - 4 * x - z * z);
        points_z[index] += timeStep * (-1.89 * z - 4 * x - 4 * y - x * x);
        
        // Sprott Attractor
        //points_x[index] += timeStep * (y + 2.07 * x * y + x * z);
        //points_y[index] += timeStep * (1 - 1.79 * x * x + y * z);
        //points_z[index] += timeStep * (x - x * x - y * y);
      
        //  Attractor
        //points_x[index] += timeStep * ();
        //points_y[index] += timeStep * ();
        //points_z[index] += timeStep * ();
      }
    }
    
    // Transform point locations into coordinates relative to camera's POV
    relativeX = COBM[0][0] * (x - cameraPosition_xyz[0]) + COBM[0][1] * (y - cameraPosition_xyz[1]) + COBM[0][2] * (z - cameraPosition_xyz[2]);
    relativeY = COBM[1][0] * (x - cameraPosition_xyz[0]) + COBM[1][1] * (y - cameraPosition_xyz[1]) + COBM[1][2] * (z - cameraPosition_xyz[2]);
    relativeZ = COBM[2][0] * (x - cameraPosition_xyz[0]) + COBM[2][1] * (y - cameraPosition_xyz[1]) + COBM[2][2] * (z - cameraPosition_xyz[2]);
    
    // Hide points at or behind camera
    if (relativeY <= ZERO_TOLERANCE) { continue; }
    
    // Project onto plane of 2D screen
    screenX = int(map(relativeX / relativeY, -float(width) / height, float(width) / height, 0, (width - 1)));
    screenY = int(map(relativeZ / relativeY, -1, 1, (height - 1), 0));
    
    // Hide points beyond edges of screen
    if (screenX > (width - 1) || screenX < 0 || screenY > (height - 1) || screenY < 0) { continue; }
    
    stroke(0);
    if (index >= NUMBER_OF_POINTS - 8)
    {
      // Box frame vertices for reference
      fill(255, 0, 0);
      circle(screenX, screenY, 4);
    }
    else
    {
      // Points to be updated
      //if (sqrt(pow(cameraPosition_xyz[0] - x,2) + pow(cameraPosition_xyz[1] - y,2) + pow(cameraPosition_xyz[2] - z,2)) < MAX_RADIUS)
      if (dist(cameraPosition_xyz[0], cameraPosition_xyz[1], cameraPosition_xyz[2], x, y, z) < MAX_RADIUS)
      {
        // Still actively within maximum radius
        fill(0, 255, 0);
      }
      else
      {
        fill(0, 0, 255);
      }
      
      circle(screenX, screenY, 4);
    }
  }
  
  // Animation
  
  //time += 1;
  //time = (time + 360) % 360;
  
  // GUI / Simulation Controls
  stroke(0);
  textAlign(CENTER, CENTER);
  textSize(20);
  
  // HUD Control
  if (HUD_On)
  {
    fill(0, 255, 0);
    rect(width - 50, 0, 50, 50);
    fill(0);
  }
  else
  {
    fill(255, 0, 0);
    rect(width - 50, 0, 50, 50);
    fill(255);
  }
  text("HUD", width - 25, 25);
  
  // RUN Control
  if (runSimulation)
  {
    fill(0, 255, 0);
    rect(width - 50, 50, 50, 50);
    fill(0);
  }
  else
  {
    fill(255, 0, 0);
    rect(width - 50, 50, 50, 50);
    fill(255);
  }
  text("RUN", width - 25, 75);
  
  // RST Control
  if (resetSimulation)
  {
    fill(0, 255, 0);
    rect(width - 50, 100, 50, 50);
    fill(0);
  }
  else
  {
    fill(255, 0, 0);
    rect(width - 50, 100, 50, 50);
    fill(255);
  }
  text("RST", width - 25, 125);
  
  if (dimensionUnlock == 0)
  {
    fill(0, 255, 0);
    rect(width - 50, 200, 50, 50);
    fill(0);
  }
  else
  {
    fill(255, 0, 0);
    rect(width - 50, 200, 50, 50);
    fill(255);
  }
  text("X", width - 25, 225);
  
  if (dimensionUnlock == 1)
  {
    fill(0, 255, 0);
    rect(width - 50, 250, 50, 50);
    fill(0);
  }
  else
  {
    fill(255, 0, 0);
    rect(width - 50, 250, 50, 50);
    fill(255);
  }
  text("Y", width - 25, 275);
  
  if (dimensionUnlock == 2)
  {
    fill(0, 255, 0);
    rect(width - 50, 300, 50, 50);
    fill(0);
  }
  else
  {
    fill(255, 0, 0);
    rect(width - 50, 300, 50, 50);
    fill(255);
  }
  text("Z", width - 25, 325);
  
  // HUD
  if (HUD_On)
  {
    fill(0, 255, 0);
    textAlign(LEFT, TOP);
    textSize(12);
    
    // Camera position
    text("CAMERA POSITION:", 10, 10);
    text("CamPos Lat: " + truncate(cameraPosition_lat) + ", Lon: " + truncate(cameraPosition_lon), 10, 30);
    text("CamPos XYZ: " + truncate(cameraPosition_xyz[0]) + " / " + truncate(cameraPosition_xyz[1]) + " / " + truncate(cameraPosition_xyz[2]), 10, 50);
    text("CamOff XYZ: " + str(cameraOffset_xyz[0]) + " / " + str(cameraOffset_xyz[1]) + " / " + str(cameraOffset_xyz[2]), 10, 70);
    
    // Camera orientation
    text("CAMERA ORIENTATION:", 10, 110);
    text("CamOri Lat: " + str(cameraOrientation_lat) + " Lon: " + str(cameraOrientation_lon), 10, 130);
    text("CamPOV i: " + truncate(cameraPOV_i[0]) + " / " + truncate(cameraPOV_i[1]) + " / " + truncate(cameraPOV_i[2]), 10, 150);
    text("CamPOV j: " + truncate(cameraPOV_j[0]) + " / " + truncate(cameraPOV_j[1]) + " / " + truncate(cameraPOV_j[2]), 10, 170);
    text("CamPOV k: " + truncate(cameraPOV_k[0]) + " / " + truncate(cameraPOV_k[1]) + " / " + truncate(cameraPOV_k[2]), 10, 190);
    
    // COBM
    text("CHANGE OF BASIS MATRIX:", 10, 230);
    text("[ " + truncate(COBM[0][0]) + " / " + truncate(COBM[0][1]) + " / " + truncate(COBM[0][2]) + " ]", 10, 250);
    text("[ " + truncate(COBM[1][0]) + " / " + truncate(COBM[1][1]) + " / " + truncate(COBM[1][2]) + " ]", 10, 270);
    text("[ " + truncate(COBM[2][0]) + " / " + truncate(COBM[2][1]) + " / " + truncate(COBM[2][2]) + " ]", 10, 290);
    
    // Camera radius
    text("Camera Radius: " + str(cameraRadius), 10, 330);
    
    // Graphical angle depictions
    textAlign(CENTER, CENTER);
    textSize(15);
    text("LAT", width - 250, 70);
    text("LON", width - 120, 70);
    
    noFill();
    stroke(255);
    circle(width - 120, 70, 100);
    circle(width - 250, 70, 100);
    
    fill(200, 100, 0);
    circle((width - 120) + 50 * cos(radians(cameraPosition_lon)), 70 - 50 * sin(radians(cameraPosition_lon)), 20);
    circle((width - 250) + 50 * cos(radians(cameraPosition_lat)), 70 - 50 * sin(radians(cameraPosition_lat)), 20);
  }
  
  textAlign(RIGHT, BOTTOM);
  textSize(20);
  fill(255);
  text("ChaotoDot", width - 10, height - 10);
}
