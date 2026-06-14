/*
 * Author: Warmacha
 * Edited By: N/A
 * Company: RedJacks
 * Project: Project Dimension
 * Description: Creates shadow-casting proxy geometry for billboarded sprites
 * Created: 2026-01-08
 * Last Modified: 2026-01-08
 */

using UnityEngine;

namespace RedJacks.Gameplay.Rendering
{
	public class SpriteShadowProxy : MonoBehaviour
	{
		[Header("Shadow Proxy Settings")]
		[Tooltip("Automatically create a simple quad proxy on Start")]
		public bool autoCreateProxy = true;
		
		[Tooltip("Height of the shadow proxy mesh")]
		public float proxyHeight = 2f;
		
		[Tooltip("Width of the shadow proxy mesh")]
		public float proxyWidth = 1f;
		
		[Tooltip("Offset the proxy vertically (to align with sprite pivot)")]
		public float verticalOffset = 0f;
		
		[Header("Advanced")]
		[Tooltip("Use cross-quad for better shadow coverage from all angles")]
		public bool useCrossQuad = true;
		
		[Tooltip("Keep shadow proxy world-aligned (doesn't rotate with billboard)")]
		public bool keepWorldAligned = true;
		
		[Tooltip("Material to use for shadow proxy (leave null for default)")]
		[SerializeField]
		private Material shadowProxyMaterial;


		#region Private Variables
		
		private GameObject shadowProxyObject;
		
		#endregion


		#region Unity Lifecycle

		private void Start()
		{
			if (autoCreateProxy)
			{
				CreateShadowProxy();
			}
		}

		private void LateUpdate()
		{
			// Keep shadow proxy world-aligned if enabled
			if (keepWorldAligned && shadowProxyObject != null)
			{
				UpdateShadowProxyTransform();
			}
		}

		private void OnDestroy()
		{
			if (shadowProxyObject != null)
			{
				Destroy(shadowProxyObject);
			}
		}

		private void OnValidate()
		{
			// Recreate proxy when parameters change in editor
			if (Application.isPlaying && shadowProxyObject != null)
			{
				Destroy(shadowProxyObject);
				CreateShadowProxy();
			}
		}

		#endregion



		#region Shadow Proxy Creation

		private void CreateShadowProxy()
		{
			shadowProxyObject = new GameObject("ShadowProxy");
			
			if (keepWorldAligned)
			{
				// Don't parent to sprite - keep independent world position/rotation
				shadowProxyObject.transform.position = transform.position + Vector3.up * verticalOffset;
				shadowProxyObject.transform.rotation = Quaternion.identity;
			}
			else
			{
				// Parent to sprite - rotates with billboard
				shadowProxyObject.transform.SetParent(transform);
				shadowProxyObject.transform.localPosition = Vector3.up * verticalOffset;
				shadowProxyObject.transform.localRotation = Quaternion.identity;
			}
			
			// Try to set to ShadowOnly layer if it exists, otherwise use default
			int shadowLayer = LayerMask.NameToLayer("ShadowOnly");
			if (shadowLayer == -1)
			{
				shadowLayer = LayerMask.NameToLayer("Default");
				#if UNITY_EDITOR || DEVELOPMENT_BUILD
				Debug.LogWarning("(SpriteShadowProxy - CreateShadowProxy) 'ShadowOnly' layer not found. Using Default layer. Create a 'ShadowOnly' layer and exclude it from camera culling for best results.");
				#endif
			}
			shadowProxyObject.layer = shadowLayer;

			if (useCrossQuad)
			{
				CreateCrossQuadMesh();
			}
			else
			{
				CreateSimpleQuadMesh();
			}

			// Configure mesh renderer for shadows only
			MeshRenderer renderer = shadowProxyObject.GetComponent<MeshRenderer>();
			if (renderer != null)
			{
				renderer.shadowCastingMode = UnityEngine.Rendering.ShadowCastingMode.ShadowsOnly;
				renderer.receiveShadows = false;
				
				// Apply custom material if provided
				if (shadowProxyMaterial != null)
				{
					renderer.material = shadowProxyMaterial;
				}
			}
		}

		private void CreateSimpleQuadMesh()
		{
			Mesh mesh = new Mesh();
			mesh.name = "ShadowProxyQuad";

			// Simple vertical quad
			Vector3[] vertices = new Vector3[4]
			{
				new Vector3(-proxyWidth * 0.5f, 0, 0),
				new Vector3(proxyWidth * 0.5f, 0, 0),
				new Vector3(-proxyWidth * 0.5f, proxyHeight, 0),
				new Vector3(proxyWidth * 0.5f, proxyHeight, 0)
			};

			int[] triangles = new int[6] { 0, 2, 1, 2, 3, 1 };
			
			Vector2[] uv = new Vector2[4]
			{
				new Vector2(0, 0),
				new Vector2(1, 0),
				new Vector2(0, 1),
				new Vector2(1, 1)
			};

			mesh.vertices = vertices;
			mesh.triangles = triangles;
			mesh.uv = uv;
			mesh.RecalculateNormals();
			mesh.RecalculateBounds();

			MeshFilter meshFilter = shadowProxyObject.AddComponent<MeshFilter>();
			meshFilter.mesh = mesh;
			shadowProxyObject.AddComponent<MeshRenderer>();
		}

		private void CreateCrossQuadMesh()
		{
			Mesh mesh = new Mesh();
			mesh.name = "ShadowProxyCross";

			// Cross-shaped quads (two quads at 90 degrees)
			Vector3[] vertices = new Vector3[8]
			{
				// First quad (facing forward/back)
				new Vector3(-proxyWidth * 0.5f, 0, 0),
				new Vector3(proxyWidth * 0.5f, 0, 0),
				new Vector3(-proxyWidth * 0.5f, proxyHeight, 0),
				new Vector3(proxyWidth * 0.5f, proxyHeight, 0),
				
				// Second quad (facing left/right)
				new Vector3(0, 0, -proxyWidth * 0.5f),
				new Vector3(0, 0, proxyWidth * 0.5f),
				new Vector3(0, proxyHeight, -proxyWidth * 0.5f),
				new Vector3(0, proxyHeight, proxyWidth * 0.5f)
			};

			int[] triangles = new int[12]
			{
				// First quad
				0, 2, 1, 2, 3, 1,
				// Second quad
				4, 6, 5, 6, 7, 5
			};

			Vector2[] uv = new Vector2[8]
			{
				new Vector2(0, 0), new Vector2(1, 0), new Vector2(0, 1), new Vector2(1, 1),
				new Vector2(0, 0), new Vector2(1, 0), new Vector2(0, 1), new Vector2(1, 1)
			};

			mesh.vertices = vertices;
			mesh.triangles = triangles;
			mesh.uv = uv;
			mesh.RecalculateNormals();
			mesh.RecalculateBounds();

			MeshFilter meshFilter = shadowProxyObject.AddComponent<MeshFilter>();
			meshFilter.mesh = mesh;
			shadowProxyObject.AddComponent<MeshRenderer>();
		}

		private void UpdateShadowProxyTransform()
		{
			// Update position to follow sprite, but keep rotation world-aligned
			shadowProxyObject.transform.position = transform.position + Vector3.up * verticalOffset;
			shadowProxyObject.transform.rotation = Quaternion.identity;
		}

		#endregion



		#region Public API

		/// <summary>
		/// Manually recreate the shadow proxy with current settings
		/// </summary>
		public void RecreateProxy()
		{
			if (shadowProxyObject != null)
			{
				Destroy(shadowProxyObject);
			}
			CreateShadowProxy();
		}

		/// <summary>
		/// Enable or disable shadow casting
		/// </summary>
		public void SetShadowCastingEnabled(bool enabled)
		{
			if (shadowProxyObject == null)
			{
				return;
			}

			MeshRenderer renderer = shadowProxyObject.GetComponent<MeshRenderer>();
			if (renderer != null)
			{
				renderer.shadowCastingMode = enabled 
					? UnityEngine.Rendering.ShadowCastingMode.ShadowsOnly 
					: UnityEngine.Rendering.ShadowCastingMode.Off;
			}
		}

		#endregion
	}
}
