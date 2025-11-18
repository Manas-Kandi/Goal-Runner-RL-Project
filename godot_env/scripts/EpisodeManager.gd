extends Node
## Episode Manager for Goal Runner RL Environment
## Tracks episode statistics and manages UI updates

# Statistics tracking
var total_episodes = 0
var successful_episodes = 0
var total_rewards = 0.0
var episode_history = []
const MAX_HISTORY_SIZE = 100

# References
var agent: CharacterBody2D
var training_info_label: Label
var episode_counter_label: Label

func _ready():
	# Find references
	agent = get_node("../Agent")
	training_info_label = get_node("../UI/TrainingInfo")
	episode_counter_label = get_node("../UI/EpisodeCounter")
	
	# Start update timer
	var timer = Timer.new()
	timer.wait_time = 0.1  # Update UI every 100ms
	timer.timeout.connect(_update_ui)
	timer.autostart = true
	add_child(timer)

func _update_ui():
	if not agent or not training_info_label:
		return
	
	var stats = agent.get_episode_stats()
	
	# Update training info
	var status = "Running"
	if stats.done:
		status = "Success" if stats.success else "Failed"
	
	training_info_label.text = "Episode: %d\nSteps: %d\nReward: %.2f\nStatus: %s" % [
		total_episodes,
		stats.steps,
		stats.reward,
		status
	]
	
	# Update episode counter
	var success_rate = 0.0
	if total_episodes > 0:
		success_rate = (float(successful_episodes) / float(total_episodes)) * 100.0
	
	var avg_reward = 0.0
	if total_episodes > 0:
		avg_reward = total_rewards / float(total_episodes)
	
	episode_counter_label.text = "Success Rate: %.1f%%\nAvg Reward: %.2f" % [
		success_rate,
		avg_reward
	]

func on_episode_complete(stats: Dictionary):
	"""Called when an episode completes"""
	total_episodes += 1
	
	if stats.success:
		successful_episodes += 1
	
	total_rewards += stats.reward
	
	# Add to history
	episode_history.append({
		"episode": total_episodes,
		"steps": stats.steps,
		"reward": stats.reward,
		"success": stats.success
	})
	
	# Trim history if needed
	if episode_history.size() > MAX_HISTORY_SIZE:
		episode_history.pop_front()
	
	# Log to console
	print("Episode %d complete: Steps=%d, Reward=%.2f, Success=%s" % [
		total_episodes,
		stats.steps,
		stats.reward,
		"Yes" if stats.success else "No"
	])

func get_statistics() -> Dictionary:
	"""Returns comprehensive episode statistics"""
	var success_rate = 0.0
	if total_episodes > 0:
		success_rate = float(successful_episodes) / float(total_episodes)
	
	var avg_reward = 0.0
	var avg_steps = 0.0
	if episode_history.size() > 0:
		var total_steps = 0
		var total_reward_history = 0.0
		for ep in episode_history:
			total_steps += ep.steps
			total_reward_history += ep.reward
		avg_steps = float(total_steps) / float(episode_history.size())
		avg_reward = total_reward_history / float(episode_history.size())
	
	return {
		"total_episodes": total_episodes,
		"successful_episodes": successful_episodes,
		"success_rate": success_rate,
		"avg_reward": avg_reward,
		"avg_steps": avg_steps,
		"recent_history": episode_history.slice(-10)  # Last 10 episodes
	}

func reset_statistics():
	"""Resets all episode statistics"""
	total_episodes = 0
	successful_episodes = 0
	total_rewards = 0.0
	episode_history.clear()
