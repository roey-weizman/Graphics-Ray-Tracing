
 #version 130 

uniform vec4 eye;
uniform vec4 ambient;
uniform vec4[20] objects;
uniform vec4[20] objColors;
uniform vec4[10] lightsDirection;
uniform vec4[10] lightsIntensity;
uniform vec4[10] lightPosition;
uniform ivec3 sizes; //number of objects & number of lights

in vec3 position1;

int index; //the index of the object that is closest to the eye that intersects position1.
vec3 normal; //normal to intersectPoint on objects[index];
vec3 eye1 = eye.xyz;
vec3 intersectPoint;
bool withMirror = false;
bool isPlane =false;

float rayPlaneIntersect(vec3 r0, vec3 rd, vec3 s0, float d)
 {
    // - r0: ray origin - rd: normalized ray direction
    // - s0: plane normal - d: plane D
    // - Returns distance from r0 to first intersecion with plane,
    //   or -1.0 if no intersection.
	s0= normalize(s0);
	rd= normalize(rd);

	float mone = d+dot(r0,s0);
	float mechane = dot(rd,s0);
	float distance = -mone/mechane;
	if(distance > 0.0001)
		return distance;
	return -1.0;
}

float raySphereIntersect(vec3 r0, vec3 rd, vec3 s0, float sr)
 {
    // - r0: ray origin - rd: normalized ray direction
    // - s0: sphere center - sr: sphere radius
    // - Returns distance from r0 to first intersecion with sphere,
    //   or -1.0 if no intersection.
    rd = normalize(rd);
	float a = dot(rd, rd);
    vec3 s0_r0 = r0 - s0;
    float b = 2.0 * dot(rd, s0_r0);
    float c = dot(s0_r0, s0_r0) - (sr * sr);
    if (b*b - 4.0*a*c < 0.0) {
        return -1.0;
    }
    float first =  (-b - sqrt((b*b) - 4.0*a*c))/(2.0*a);
	if(first > 0.0001)
		return first;
    return (-b + sqrt((b*b) - 4.0*a*c))/(2.0*a);
}

//scans all the objects in the scene and returns the color of the object that is for this position1.
vec4 AmbientCalc(vec3 from, vec3 direction)
{	
	float distance = -1.0;
	float maxdistance = 100000;
	vec4 color = vec4(0,0,0,0);
	
	for(int i = 0; i< sizes.x;i++)
	{
		if(objects[i].w > 0)
		{	
			distance = raySphereIntersect (from,direction,objects[i].xyz,objects[i].w);
			if(distance < maxdistance && distance > 0.0001f)
			{
				maxdistance = distance;
				color = objColors[i];
				index = i;
				intersectPoint = from+(distance)*direction;
				normal = normalize(intersectPoint - objects[i].xyz);
				isPlane = false;
			}
		}
		else
		{	
			direction = normalize(direction);
			distance = rayPlaneIntersect (from,direction,objects[i].xyz,objects[i].w);
			if(distance < maxdistance && distance != -1.0f)
			{
				maxdistance = distance;
				color =objColors[i];
				index = i;
				intersectPoint = from+(distance)*direction;
				normal = -normalize(objects[i].xyz);
				isPlane = true;
			}
		}
	}				
	return color;
}

vec3 makePlaneDesign(vec3 color)
{
	if(intersectPoint.x*intersectPoint.y>0)
	{
		if(mod(int(1.5*intersectPoint.x),2) == mod(int(1.5*intersectPoint.y),2))
		{
			color*=0.5;
		}				
	}
	else
	{
		if(mod(int(1.5*intersectPoint.x),2) != mod(int(1.5*intersectPoint.y),2))
		{
			color*=0.5;
		}
	}
	return color;
}

bool intersectObject(vec3 from, vec3 direction, int type,float minD,float dist)
{
	bool ans = false;
	float minDistance= 100000;
	float distance = -1.0f;
	if(minD != 0)
		 minDistance = minD;

	for(int i =0; i< sizes.x ;i++)
	{   
		if(objects[i].w > 0)
		{
			distance = raySphereIntersect (from,direction,objects[i].xyz,objects[i].w);
			if(distance > 0.0001 && minDistance > distance){
				ans = true;
				minDistance = distance;
				type = 0;
			}
		}
		else
		{
			distance = rayPlaneIntersect (from,direction,objects[i].xyz ,objects[i].w);
			if(distance > 0.0001 && minDistance > distance && distance<dist){
				ans = true;
				minDistance = distance;
				type = 1;
			}
		}
	}
	return ans;
}

vec3 calcDiffuse(vec3 L)
{
	vec3 Kd = objColors[index].xyz;
	vec3 diffuse = Kd*max(dot(normal,normalize(-L)),0);
	if(isPlane)
		diffuse = makePlaneDesign(diffuse);
	diffuse = clamp(diffuse, vec3(0.0,0.0,0.0),vec3(1.0,1.0,1.0));
	if(withMirror && (isPlane) )
		return vec3(0,0,0);
return diffuse;
}

vec3 calcSpecular(vec3 L)
{
	vec3 Ks = vec3(0.7,0.7,0.7);
	vec3 u = normalize(L);
	vec3 R = normalize(u - 2*normal*dot(u,normal));
	vec3 V = normalize(eye1-intersectPoint);
	vec3 specular = Ks*max(pow(dot(V, R),objColors[index].w), 0);
	specular = clamp(specular, vec3(0.0,0.0,0.0),vec3(1.0,1.0,1.0));
	if(withMirror && isPlane)
		return vec3(0,0,0);
return specular;
}

vec4 lighting(vec3 HitOnMirror, vec3 normalOnMirror)
{
	vec4 color;
	vec3 direction; 

	for(int i = 0; i<sizes.y; i++)
	{
		int numOfIntersected = -1;
		if(lightsDirection[i].w == 0.0)				//directinal light
		{
			direction = normalize(lightsDirection[i].xyz);			
			if(!intersectObject(intersectPoint,-direction,numOfIntersected,0,0))
			{
				color += (vec4(calcDiffuse(direction),1.0) + vec4(calcSpecular(direction),1.0))*lightsIntensity[i];
				color = clamp(color, vec4(0.0,0.0,0.0,0.0),vec4(1.0,1.0,1.0,1.0));
			}
				if(withMirror && HitOnMirror.z != 1)
			{
				vec3 u = normalize(lightsDirection[i].xyz);
				direction = normalize(u - 2*normalOnMirror*dot(u,normalOnMirror));
				color += (vec4(calcDiffuse(direction),1.0) + vec4(calcSpecular(direction),1.0))*lightsIntensity[i];
			}
		}
		else if(lightsDirection[i].w == 1.0)		//spot light
		{
			direction = normalize(intersectPoint - lightPosition[i].xyz);
			if(dot(direction,normalize(lightsDirection[i].xyz))>lightPosition[i].w)
				if(!intersectObject(intersectPoint,-direction,numOfIntersected,0,distance(intersectPoint,lightPosition[i].xyz)))
				{
					color += (vec4(calcDiffuse(direction),1.0) + vec4(calcSpecular(direction),1.0))*lightsIntensity[i];
					color = clamp(color, vec4(0.0,0.0,0.0,0.0),vec4(1.0,1.0,1.0,1.0));
				}
				if(withMirror && HitOnMirror.z != 1)				{
				vec3 u = direction;
				direction = normalize(u - 2*normalOnMirror*dot(u,normalOnMirror));
				color += (vec4(calcDiffuse(direction),1.0) + vec4(calcSpecular(direction),1.0))*lightsIntensity[i];
				}
		}
	}
	return color;
}

vec4 colorCalc( vec3 intersectionPoint)
{	
	withMirror = (eye.w == 0.0);

	vec4 color = ambient*AmbientCalc(eye1,normalize(position1-eye1)) + lighting(vec3(1,1,1),vec3(1,1,1)); 
	if(withMirror && isPlane)
	{
		vec3 u = normalize(position1-eye1);
		vec3 R = normalize(u - 2*normal*dot(u,normal));
		vec3 intersectOnMirror = intersectPoint+vec3(0.001,0.001,0.001);
		vec3 normalOnMirror = normal;
		color =AmbientCalc(intersectOnMirror,R) + lighting(intersectOnMirror,normalOnMirror);
	}
		 
    return color;
}

void main()
{  
	gl_FragColor = vec4(colorCalc(eye.xyz));      
}