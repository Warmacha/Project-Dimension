/*
 * Author: Warmacha
 * Edited By: N/A
 * Company: RedJacks
 * Project: Project Dimension
 * Description: Billboard script that rotates sprites to face the camera
 * Created: 2026-01-08
 * Last Modified: 2026-01-08
 */

using UnityEngine;

namespace RedJacks.Gameplay.Rendering
{
	public class SpriteBillboarding : MonoBehaviour
	{
		[Header("Billboard Settings")]
		[Tooltip("Target camera for billboarding. If null, uses Camera.main")]
		public Camera mainCamera;

		[Tooltip("If true, sprite faces away from camera instead of toward it")]
		public bool reverseDirection = false;


		#region Unity Lifecycle

		private void Update()
		{
			UpdateBillboard();
		}

		#endregion



		#region Billboard

		private void UpdateBillboard()
		{
			Camera targetCamera = mainCamera == null ? Camera.main : mainCamera;

			if (targetCamera == null)
			{
				#if UNITY_EDITOR || DEVELOPMENT_BUILD
				Debug.LogWarning("(SpriteBillboarding - UpdateBillboard) No camera found for billboarding");
				#endif
				return;
			}

			Vector3 lookPosition = targetCamera.transform.position;

			if (reverseDirection)
			{
				Vector3 directionAway = transform.position - lookPosition;
				lookPosition = transform.position + directionAway;
			}

			transform.LookAt(lookPosition, Vector3.up);
		}

		#endregion
	}
}
