// ----- CONTROL VARIABLES ----- //

float ZERO_TOLERANCE = 0.0001;

// Camera position (deg / XYZ)
int cameraPosition_lat, cameraPosition_lon;
float[] cameraPosition_xyz = new float[3];
int cameraRadius = 5;

// Camera orientation (deg)
int cameraOrientation_lat, cameraOrientation_lon;

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

// GUI Controls
boolean HUD_On = false;

// Point updating
float timeStep = 0.01;
float x, y, z;

// ----- HELPER FUNCTIONS ----- //

void LatLon_toXYZ(int lat, int lon, float[] xyz, int radius)
{
  xyz[0] = radius * cos(radians(lat)) * cos(radians(lon));
  xyz[1] = radius * cos(radians(lat)) * sin(radians(lon));
  xyz[2] = radius * sin(radians(lat));
}

String truncate(float value)
{
  return str(round(value * 100) / 100.0);
}

// ----- CORE FUNCTIONS ----- //

void mousePressed()
{
  if (mouseX >= (width - 50) && mouseY <= 50)
  {
    HUD_On = !HUD_On;
  }
}

void mouseDragged()
{
  lastMouseX = mouseX;
  lastMouseY = mouseY;
}

void mouseWheel(MouseEvent e)
{
  if (e.getCount() > 0)
  {
    cameraRadius++;
  }
  else
  {
    cameraRadius--;
    if (cameraRadius < 0) { cameraRadius = 0; }
  }
}

void setup()
{
  // Vector / Matrix initializations
  for (int i = 0; i < 3; i++)
  {
    // 1D vectors (Dimension 3)
    cameraPosition_xyz[i] = float(0);
    
    for (int j = 0; j < 3; j++)
    {
      // 2D matrix (Dimension 3x3)
      COBM[i][j] = float(0);
    }
  }
  
  // Populate random starter points
  for (int i = 0; i < NUMBER_OF_POINTS - 8; i++)
  {
    points_x[i] = random(-1, 1);
    points_y[i] = random(-1, 1);
    points_z[i] = random(-1, 1);
  }
  
  // Setup starter box
  int currentPoint = NUMBER_OF_POINTS - 8;
  for (int x = -1; x <= 1; x += 2)
  {
    for (int y = -1; y <= 1; y += 2)
    {
      for (int z = -1; z <= 1; z += 2)
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
  
  // Camera position
  cameraPosition_lat = round(map(lastMouseY, 0, (height - 1), -90, 90));
  cameraPosition_lon = round(map(lastMouseX, 0, (width - 1), 720, 0));
  LatLon_toXYZ(cameraPosition_lat, cameraPosition_lon, cameraPosition_xyz, cameraRadius);
  
  // Camera orientation
  cameraOrientation_lat = -cameraPosition_lat;
  cameraOrientation_lon = (cameraPosition_lon + 180 + 360) % 360;
  
  // Camera POV directions
  LatLon_toXYZ(0, cameraOrientation_lon - 90, cameraPOV_i, 1);
  LatLon_toXYZ(cameraOrientation_lat, cameraOrientation_lon, cameraPOV_j, 1);
  LatLon_toXYZ(cameraOrientation_lat + 90, cameraOrientation_lon, cameraPOV_k, 1);
  
  // Change of basis matrix
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
  COBM[0][0] = (e * i - f * h) / determinant;
  COBM[0][1] = -(b * i - c * h) / determinant;
  COBM[0][2] = (b * f - c * e) / determinant;
  COBM[1][0] = -(d * i - f * g) / determinant;
  COBM[1][1] = (a * i - c * g) / determinant;
  COBM[1][2] = -(a * f - c * d) / determinant;
  COBM[2][0] = (d * h - e * g) / determinant;
  COBM[2][1] = -(a * h - b * g) / determinant;
  COBM[2][2] = (a * e - b * d) / determinant;
  
  // Point display / Render pipeline
  
  for (int index = 0; index < NUMBER_OF_POINTS; index++)
  { 
    // Create static copy of current point location so original copy can be updated
    x = points_x[index];
    y = points_y[index];
    z = points_z[index];
    
    if (index < NUMBER_OF_POINTS - 8)
    {
      // Update point location according to formulas
      points_x[index] += timeStep * (-1.89 * x - 4 * y - 4 * z - y * y);
      points_y[index] += timeStep * (-1.89 * y - 4 * z - 4 * x - z * z);
      points_z[index] += timeStep * (-1.89 * z - 4 * x - 4 * y - x * x);
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
      if (sqrt(pow(cameraPosition_xyz[0] - x,2) + pow(cameraPosition_xyz[1] - y,2) + pow(cameraPosition_xyz[2] - z,2)) < MAX_RADIUS)
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
  
  // GUI Controls
  stroke(0);
  textAlign(CENTER, CENTER);
  if (HUD_On)
  {
    fill(0, 255, 0);
  }
  else
  {
    fill(255, 0, 0);
  }
  rect(width - 50, 0, 50, 50);
  if (HUD_On)
  {
    fill(0);
  }
  else
  {
    fill(255);
  }
  textSize(20);
  text("HUD", width - 25, 25);
  
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
    
    // Camera orientation
    text("CAMERA ORIENTATION:", 10, 90);
    text("CamOri Lat: " + str(cameraOrientation_lat) + " Lon: " + str(cameraOrientation_lon), 10, 110);
    text("CamPOV i: " + truncate(cameraPOV_i[0]) + " / " + truncate(cameraPOV_i[1]) + " / " + truncate(cameraPOV_i[2]), 10, 130);
    text("CamPOV j: " + truncate(cameraPOV_j[0]) + " / " + truncate(cameraPOV_j[1]) + " / " + truncate(cameraPOV_j[2]), 10, 150);
    text("CamPOV k: " + truncate(cameraPOV_k[0]) + " / " + truncate(cameraPOV_k[1]) + " / " + truncate(cameraPOV_k[2]), 10, 170);
    
    // COBM
    text("CHANGE OF BASIS MATRIX:", 10, 210);
    text("[ " + truncate(COBM[0][0]) + " / " + truncate(COBM[0][1]) + " / " + truncate(COBM[0][2]) + " ]", 10, 230);
    text("[ " + truncate(COBM[1][0]) + " / " + truncate(COBM[1][1]) + " / " + truncate(COBM[1][2]) + " ]", 10, 250);
    text("[ " + truncate(COBM[2][0]) + " / " + truncate(COBM[2][1]) + " / " + truncate(COBM[2][2]) + " ]", 10, 270);
    
    // Camera radius
    text("Camera Radius: " + str(cameraRadius), 10, 310);
  }
  
  textAlign(RIGHT, BOTTOM);
  textSize(20);
  fill(255);
  text("ChaotoDot", width - 10, height - 10);
}
