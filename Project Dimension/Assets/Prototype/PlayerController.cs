/*
 * Author: Warmacha
 * Edited By: N/A
 * Company: RedJacks
 * Project: Project Dimension
 * Description: Simple 3D player movement controller using Unity's new Input System
 * Created: 2026-01-08
 * Last Modified: 2026-01-08
 */

using UnityEngine;
using UnityEngine.InputSystem;

namespace RedJacks.Gameplay.Player
{
	[RequireComponent(typeof(Rigidbody))]
	public class PlayerController : MonoBehaviour
	{

		[Header("Movement Settings")]
		[Tooltip("Movement speed in units per second")]
		public float moveSpeed = 5f;
        public float animatorSpeed = 0.5f;
		
		[Header("References")]
		[SerializeField]
		private Animator animator;


		#region Private Variables

		private Rigidbody rb;
		private Vector2 moveInput = Vector2.zero;
		private Vector3 lastMoveDirection = Vector3.zero;

		#endregion

		private InputSystem_Actions inputActions;


		#region Unity Lifecycle

		private void Awake()
		{
			rb = GetComponent<Rigidbody>();

			inputActions = new InputSystem_Actions();

			inputActions.Player.Move.performed += OnMove;
			inputActions.Player.Move.canceled += OnMoveCanceled;
		}

		private void OnEnable()
		{
			inputActions.Enable();
		}

		private void OnDisable()
		{
			inputActions.Disable();
		}

		private void OnDestroy()
		{
			inputActions.Player.Move.performed -= OnMove;
			inputActions.Player.Move.canceled -= OnMoveCanceled;
		}

		private void FixedUpdate()
		{
			ApplyMovement();
		}

			#endregion



		#region Input Callbacks

		/// <summary>
		/// Called by Unity's Input System when the Move action is performed.
		/// </summary>
		/// <param name="context">Input action callback context</param>
		public void OnMove(InputAction.CallbackContext context)
		{
			moveInput = context.ReadValue<Vector2>();
			UpdateAnimator(true);
		}

		public void OnMoveCanceled(InputAction.CallbackContext context)
		{
			moveInput = Vector2.zero;
			UpdateAnimator(false);
		}

			#endregion



		#region Movement

		private void ApplyMovement()
		{
			// Convert 2D input to 3D movement on XZ plane
			Vector3 movement = new Vector3(moveInput.x, 0f, moveInput.y) * moveSpeed;
			
			// Preserve Y velocity (for gravity/jumping if added later)
			movement.y = rb.linearVelocity.y;
			
			rb.linearVelocity = movement;
		}

		private void UpdateAnimator(bool isMoving)
		{
			if (animator == null)
			{
				return;
			}

			if (isMoving)
			{
				// Track the last non-zero direction (in 3D space)
				lastMoveDirection = new Vector3(moveInput.x, 0f, moveInput.y);
				
				// set speed of animation based on move speed, run isn't implemented yet so just set it
				animator.SetFloat("Speed", animatorSpeed);
				
				// Set animation to 2.0 while moving
				if (moveInput.x > 0)
				{
					animator.SetFloat("Right", 2.0f);
					animator.SetFloat("Forward", 0f);
				}
				else if (moveInput.x < 0)
				{
					animator.SetFloat("Right", -2.0f);
					animator.SetFloat("Forward", 0f);
				}
				else if (moveInput.y > 0)
				{
					animator.SetFloat("Forward", 2.0f);
					animator.SetFloat("Right", 0f);
				}
				else if (moveInput.y < 0)
				{
					animator.SetFloat("Forward", -2.0f);
					animator.SetFloat("Right", 0f);
				}
			}
			else
			{
				// When we stop moving, set direction to 1.0f/-1.0f based on last direction
				if (lastMoveDirection.sqrMagnitude > 0.01f)
				{
					if (Mathf.Abs(lastMoveDirection.x) > Mathf.Abs(lastMoveDirection.z))
					{
						// Last movement was primarily horizontal (X axis)
						animator.SetFloat("Right", lastMoveDirection.x > 0 ? 1.0f : -1.0f);
						animator.SetFloat("Forward", 0f);
					}
					else
					{
						// Last movement was primarily forward/back (Z axis)
						animator.SetFloat("Forward", lastMoveDirection.z > 0 ? 1.0f : -1.0f);
						animator.SetFloat("Right", 0f);
					}
				}
			}
		}

		#endregion
	}
}