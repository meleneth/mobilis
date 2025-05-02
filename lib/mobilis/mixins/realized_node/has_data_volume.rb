module Mobilis::Mixins::RealizedNode::HasDataVolume
  def has_data_volume?
    true
  end

  def data_volume_source_path
    File.join(env.root_data_dir, node.kind_slug, node.name)
  end

  def data_volume_mount_path
    raise NotImplementedError, "#{self.class} must implement #data_volume_mount_path"
  end

  def volume_mount_spec
    "#{data_volume_source_path}:#{data_volume_mount_path}"
  end
end
