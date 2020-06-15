# activate component plugin
$c->{plugin_alias_map}->{'InputForm::Component::Documents'} =
	'InputForm::Component::RDLDocuments';
$c->{plugin_alias_map}->{'InputForm::Component::RDLDocuments'} = undef;
$c->{plugins}->{'InputForm::Component::RDLDocuments'}->{params}->{disable} = 0;

# activate RDLDeposit plugin
$c->{plugins}->{'Screen::RDLDeposit'}->{params}->{disable} = 0;

# use 'dataset' as default eprints data_type
$c->{rdl_replaced_set_eprint_defaults} = $c->{set_eprint_defaults};
$c->{set_eprint_defaults} = sub
{
	my( $data, $repository ) = @_;
	# call original eprint defaults method
	$repository->call('rdl_replaced_set_eprint_defaults', $data, $repository);
	if(!EPrints::Utils::is_set( $data->{data_type} ))
	{
		$data->{data_type} = 'dataset';
	}
};

# replace automatic field population method
$c->{rdl_replaced_set_eprint_automatic_fields} =
	$c->{set_eprint_automatic_fields};

# add default values for publisher and date if not set
$c->{set_eprint_automatic_fields} = sub
{
	my($eprint) = @_;

	#$repo->call('rdl_replaced_set_eprint_automatic_fields', $eprint);
	if(!$eprint->is_set('publisher') )
	{
		$eprint->set_value( 'publisher', 'University of Leeds' );
	}
	my $lastmod = $eprint->get_value('lastmod');
	if(!$eprint->is_set('date') )
	{
		$eprint->set_value( 'date', $lastmod );
	}
};

#  replace default document validation method
$c->{rdl_replaced_validate_document} = $c->{validate_document};

# add custom document validation method
$c->{validate_document} = sub
{
	my ($document, $repository, $for_archive) = @_;
	my $eprint = $document->get_eprint();

	if(    $eprint->value('data_type') ne 'dataset'
		&& $eprint->value('data_type') ne 'physical_object' )
	{
		return $repository->call('rdl_replaced_validate_document', $document, $repository, undef);
	}

	my @problems = ();

	my $xml = $repository->xml();

	# DOCUMENT CHECKS

	# documents of format 'other' must have formatdesc set
	if ($document->value('format') eq 'other'
		&& !EPrints::Utils::is_set($document->value('formatdesc')))
	{
		my $fieldname =
			$xml->create_element('span', class => 'ep_problem_field:documents');
		push @problems,
			$repository->html_phrase(
			'validate:need_description',
			type => $document->render_citation('brief'),
			fieldname => $fieldname
			);
	}

	# security cannot be 'public' if embargo date set
	if ($document->value('security') eq 'public'
		&& EPrints::Utils::is_set($document->value('date_embargo')))
	{
		my $fieldname =
			$xml->create_element('span', class => 'ep_problem_field:documents');
		push @problems,
			$repository->html_phrase('validate:embargo_check_security',
			fieldname => $fieldname);
	}

	# embargo expiry date capped at 2 years
	if (EPrints::Utils::is_set($document->value('date_embargo')))
	{
		my $value = $document->value('date_embargo');
		my ($thisyear, $thismonth, $thisday) = EPrints::Time::get_date_array();
		my ($year, $month, $day) = split('-', $value);
		if (   $year < $thisyear
			|| ($year == $thisyear && $month < $thismonth)
			|| ($year == $thisyear && $month == $thismonth && $day <= $thisday))
		{
			my $fieldname = $xml->create_element('span',
				class => 'ep_problem_field:documents');
			push @problems,
				$repository->html_phrase('validate:embargo_invalid_date',
				fieldname => $fieldname);
		}

		my $embargo_cap = $thisyear + 1;
		if (
			   $year > $embargo_cap
			|| ($year == $embargo_cap && $month > $thismonth)
			|| (   $year == $embargo_cap
				&& $month == $thismonth
				&& $day >= $thisday)
			)
		{
			my $fieldname = $xml->create_element('span',
				class => 'ep_problem_field:documents');
			push @problems,
				$repository->html_phrase('validate:embargo_too_far_in_future',
				fieldname => $fieldname);

		}

	}
	return (@problems);
};

# add eprint dataset fields
$c->add_dataset_field(
	'eprint',
	{
		name => 'doi',
		type => 'text',
	},
	reuse => 1
);

$c->add_dataset_field(
	'eprint',
	{
		name => 'alt_identifier',
		type => 'text',
		multiple => 1,
	},
	reuse => 1
);

$c->add_dataset_field(
	'eprint',
	{
		name => 'version',
		type => 'text',
	},
	reuse => 1
);

$c->add_dataset_field(
	'eprint',
	{
		name => 'alt_title',
		type => 'longtext',
		input_rows => 3,
	},
	reuse => 1
);

# redefinition
@{ $c->{fields}->{eprint} } =
	grep { $_->{name} ne 'creators' } @{ $c->{fields}->{eprint} };
$c->add_dataset_field(
	'eprint',
	{
		name => 'creators',
		type => 'compound',
		multiple => 1,
		fields => [
			{
				sub_name => 'name',
				type => 'name',
				hide_honourific => 1,
				hide_lineage => 1,
				family_first => 1,
			},
			{
				sub_name => 'id',
				type => 'text',
				input_cols => 20,
				allow_null => 1,
			},
			{
				sub_name => 'other_id',
				type => 'text',
				input_cols => 20,
				allow_null => 1,
			},
			{
				sub_name => 'email',
				type => 'text',
				input_cols => 20,
				allow_null => 1,
			},
		],
		input_boxes => 4,
	},
	reuse => 1
);

# redefinition
@{ $c->{fields}->{eprint} } =
	grep { $_->{name} ne 'contributors' } @{ $c->{fields}->{eprint} };
$c->add_dataset_field(
	'eprint',
	{
		name => 'contributors',
		type => 'compound',
		multiple => 1,
		fields => [
			{
				sub_name => 'type',
				type => 'namedset',
				set_name => 'rdl_contributors_types',
			},
			{
				sub_name => 'name',
				type => 'name',
				hide_honourific => 1,
				hide_lineage => 1,
				family_first => 1,
			},
			{
				sub_name => 'id',
				type => 'text',
				input_cols => 20,
				allow_null => 1,
			},
			{
				sub_name => 'other_id',
				type => 'text',
				input_cols => 20,
				allow_null => 1,
			},
			{
				sub_name => 'email',
				type => 'text',
				input_cols => 20,
				allow_null => 1,
			},
		],
		input_boxes => 4,
	},
	reuse => 1
);

$c->add_dataset_field(
	'eprint',
	{
		name => 'grant',
		type => 'text',
		multiple => 1,
	},
	reuse => 1
);

$c->add_dataset_field(
	'eprint',
	{
		name   => 'collection_date',
		type   => 'compound',
		multiple => 1,
		fields => [
			{
				sub_name   => 'from',
				type       => 'date',
				render_res => 'day',
			},
			{
				sub_name => 'to',
				type     => 'date',
			},
		],
	},
	reuse => 1
);

$c->add_dataset_field(
	'eprint',
	{
		name   => 'temporal_cover',
		type   => 'compound',
		multiple => 1,
		fields => [
			{
				sub_name   => 'from',
				type       => 'date',
				render_res => 'day',
			},
			{
				sub_name => 'to',
				type     => 'date',
			},
		],
	},
	reuse => 1
);

$c->add_dataset_field(
	'eprint',
	{
		name => 'geographic_cover',
		type => 'text',
		multiple => 1,
	},
	reuse => 1
);

$c->add_dataset_field(
	'eprint',
	{
		name   => 'bounding_box',
		type   => 'compound',
		multiple => 1,
		fields => [
			{
				sub_name => 'north_edge',
				type     => 'float',
			},
			{
				sub_name => 'east_edge',
				type     => 'float',
			},
			{
				sub_name => 'south_edge',
				type     => 'float',
			},
			{
				sub_name => 'west_edge',
				type     => 'float',
			},
		],
	},
	reuse => 1
);

$c->add_dataset_field(
	'eprint',
	{
		name       => 'collection_method',
		type       => 'longtext',
		input_rows => '10',
	},
	reuse => 1
);

$c->add_dataset_field(
	'eprint',
	{
		name       => 'legal_ethical',
		type       => 'longtext',
		input_rows => '10',
	},
	reuse => 1
);

$c->add_dataset_field(
	'eprint',
	{
		name       => 'provenance',
		type       => 'longtext',
		input_rows => '3',
	},
	reuse => 1
);

$c->add_dataset_field(
	'eprint',
	{
		name => 'language',
		type => 'namedset',
		set_name => 'rdl_languages',
		multiple => 1,

	},
	reuse => 1
);

$c->add_dataset_field(
	'eprint',
	{
		name         => 'related_resources',
		type         => 'compound',
		multiple     => 1,
		render_value => 'EPrints::Extras::render_url_truncate_end',
		fields       => [
			{
				sub_name   => 'location',
				type       => 'text',
			},
			{
				sub_name     => 'type',
				type => 'namedset',
				set_name => 'rdl_related_resources_types',

				#render_quiet => 1,
			}
		],
		input_boxes   => 1,
		input_ordered => 0,
	},
	reuse => 1
);

$c->add_dataset_field(
	'eprint',
	{
		name => 'contact',
		type => 'text',
	},
	reuse => 1
);

$c->add_dataset_field(
	'eprint',
	{
		name => 'metadata_language',
		type => 'namedset',
		set_name => 'rdl_languages',

	},
	reuse => 1
);

$c->add_dataset_field(
	'eprint',
	{
		name        => 'terms_conditions_agreement',
		type        => 'boolean',
		input_style => 'medium',
	},
	reuse => 1
);

$c->add_dataset_field(
	'eprint',
	{
		name => 'citation',
		type => 'longtext',

	},
	reuse => 1
);

$c->add_dataset_field(
	'eprint',
	{
		name => 'license',
		type => 'namedset',
		set_name => 'rdl_licenses',

	},
	reuse => 1
);

$c->add_dataset_field(
	'eprint',
	{
		name => 'data_location',
		type => 'text',

	},
	reuse => 1
);

$c->add_dataset_field(
	'eprint',
	{
		name => 'retention_date',
		type => 'date',
		render_res => 'day',
	},
	reuse => 1
);

$c->add_dataset_field(
	'eprint',
	{
		name => 'retention_action',
		type => 'text',
	},
	reuse => 1
);

$c->add_dataset_field(
	'eprint',
	{
		name => 'retention_comment',
		type => 'longtext',
	},
	reuse => 1
);

$c->add_dataset_field(
	'eprint',
	{
		name => 'restrictions',
		type => 'text',
	},
	reuse => 1
);

# redefinition (namedset)
@{ $c->{fields}->{eprint} } =
	grep { $_->{name} ne 'data_type' } @{ $c->{fields}->{eprint} };
$c->add_dataset_field(
	'eprint',
	{
		name => 'data_type',
		type => 'namedset',
		set_name => 'rdl_data_types',

	},
	reuse => 1
);

$c->add_dataset_field(
	'document',
	{
		name => 'title',
		type => 'text',
	},
	reuse => 1
);

$c->add_dataset_field(
	'document',
	{
		name => 'publication_date',
		type => 'date',
		render_res => 'year',

		#min_resolution => 'year',
	},
	reuse => 1
);

$c->add_dataset_field(
	'document',
	{
		name => 'note',
		type => 'text',
	},
	reuse => 1
);

$c->add_dataset_field(
	'document',
	{
		name => 'doi',
		type => 'text',
	},
	reuse => 1
);

$c->add_dataset_field(
	'document',
	{
		name => 'version',
		type => 'text',
	},
	reuse => 1
);

# some core fields
# redefinition (namedset)
$c->add_dataset_field(
	'document',
	{
		name => 'content',
		type => 'namedset',
		set_name => 'rdl_document_contents',
		replace_core => 1,
	},
	reuse => 1
);

# redefinition (namedset)
$c->add_dataset_field(
	'document',
	{
		name => 'license',
		type => 'namedset',
		set_name => 'rdl_licenses',
		replace_core => 1,
	},
	reuse => 1
);

#### extra metadata that extends  the summary page record - hidden by js - accessed by additional details link

push(
	@{$c->{summary_page_metadata_full}},
	qw/
		alt_title
		creators
		corp_creators
		data_type
		contributors
		funders
		collection_date
		temporal_cover
		grant
		date
		date_type
		geographic_cover
		bounding_box
		collection_method
		legal_ethical
		provenance
		note
		language
		metadata_language
		relation
		projects
		ispublished
		publisher
		restrictions
		copyright_holders
		contact_email
		lastmod
		/
);

# overide eprint_render

$c->{rdl_replaced_eprint_render} = $c->{eprint_render};

$c->{eprint_render} = sub
{

	my ($eprint, $repository, $preview) = @_;

	if(    $eprint->value('data_type') ne 'dataset'
		&& $eprint->value('data_type') ne 'physical_object')
	{
		return $repository->call('rdl_replaced_eprint_render',
			$eprint, $repository, $preview);
	}

	my $succeeds_field   = $repository->dataset('eprint')->field('succeeds');
	my $commentary_field = $repository->dataset('eprint')->field('commentary');

	my $flags = {
		has_multiple_versions => $eprint->in_thread($succeeds_field),
		in_commentary_thread  => $eprint->in_thread($commentary_field),
		preview               => $preview,
	};

	my %fragments = ();

	# insert message that document has other versions if appropriate
	if ($flags->{has_multiple_versions})
	{
		my $latest = $eprint->last_in_thread($succeeds_field);

		if ($latest->value('eprintid') == $eprint->value('eprintid'))
		{
			$flags->{latest_version} = 1;
			$fragments{multi_info} =
				$repository->html_phrase('page:latest_version');
		}
		else
		{
			$fragments{multi_info} =$repository->render_message(
				'warning',
				$repository->html_phrase(
					'page:not_latest_version',
					link => $repository->render_link($latest->get_url())
				)
			);
		}
	}

	# Now show the version and commentary response threads
	if ($flags->{has_multiple_versions})
	{
		$fragments{version_tree} =
			$eprint->render_version_thread($succeeds_field);
	}

	if ($flags->{in_commentary_thread})
	{
		$fragments{commentary_tree} =
			$eprint->render_version_thread($commentary_field);
	}

	#add div to append file content to
	my $div_right =
		$repository->make_element('div', class => 'rd_citation_right');

	#add doc frag to add content to
	my $rddocsfrag = $repository->make_doc_fragment;

	#Add main Available Files h2 heading
	#Check if there are docs to display, if not print No files to display

	my $heading = $repository->make_element('h2', class => 'file_list_heading');
	$heading->appendChild($repository->make_text(' Files'));
	$rddocsfrag->appendChild($heading);

	if (scalar( $eprint->get_all_documents() ) eq 0)
	{

		my $nodocs =$repository->make_element('p', class => 'file_list_nodocs');
		$nodocs->appendChild($repository->make_text(' No Files to display'));
		$rddocsfrag->appendChild($nodocs);

	} ## end if ($doc_check eq 0)

	# add hashref to store content types and associated files
	my $rdfiles = {};

	# get all documents from the eprint, then add each content type and associated files as a hash key and an array of values
	foreach my $rddoc ($eprint->get_all_documents())

	{

		my $content = $rddoc->get_value('content');
		{

			if (defined($content) && $content eq 'data')
			{
				push @{$rdfiles->{'rdldata'}}, $rddoc;
			}
			elsif (defined($content) && $content eq 'documentation')
			{
				push @{$rdfiles->{'rdldocumentation'}}, $rddoc;
			}
			elsif (defined($content) && $content eq 'metadata')
			{
				push @{$rdfiles->{'rdlmetadata'}}, $rddoc;
			}
			elsif (defined($content) && $content eq 'program')
			{
				push @{$rdfiles->{'rdlprogram'}}, $rddoc;
			}

		}
	}

	# add a list of constants to generate our headings
	my $list = {

		'rdldata'          => 'Data',
		'rdldocumentation' => 'Documentation',
		'rdlmetadata'      => 'Metadata',
		'rdlprogram'       => 'Program'

	};

	# loop through a list of content types adding a header if files exist in the array
	foreach my $content_type (qw/ rdldata rdldocumentation rdlmetadata rdlprogram /)
	{
		next unless (defined $rdfiles->{$content_type});
		my $rdheading = $repository->make_element('h2', class => 'file_title');
		$rdheading->appendChild($repository->make_text($list->{$content_type}));
		$rddocsfrag->appendChild($rdheading);

		# add a table to hold filenames if files exist
		# begin rd table
		my $rdtable =$repository->make_element(
			'table',
			border      => '0',
			cellpadding => '2',
			width       => '100%'
		);

		$rddocsfrag->appendChild($rdtable);

		# for each document add a table row
		foreach my $rdfile (@{$rdfiles->{$content_type}})

		{
			my $tr  = $repository->make_element('tr');
			my $tdr = $repository->make_element('td', class => 'files_box');
			my $trm = $repository->make_element('tr');
			$tr->appendChild($tdr);

			# get url and render filename as link
			my $a = $repository->render_link($rdfile->get_url);

			my $filetmp =
				substr($rdfile->get_url, (rindex($rdfile->get_url, '/') + 1));

		  # check length of url first, if more than 60 chars truncate the middle
			my $len = 60;
			my $filetmp_trunc;
			if (length($filetmp) > $len)
			{
				$filetmp_trunc =
					  substr($filetmp, 0, $len / 2) . ' ... '
					. substr($filetmp, -$len / 2);
			}
			else
			{
				$filetmp_trunc = $filetmp;
			}

			#generate a doc id for javascript to target
			my $docid      = $rdfile->get_id;
			my $doc_prefix = '_doc_' . $docid;

			#add filemeta div
			my $filemetadiv =$repository->make_element(
				'div',
				id    => $doc_prefix . '_filemetadiv',
				class => 'rd_full'
			);

			#Add table to hold filemeta
			my $filetable =$repository->make_element(
				'table',
				id          => 'filemeta',
				border      => '0',
				cellpadding => '2',
				width       => '100%'
			);

			#Render a row to hold the link to  extended metadata
			#If a value exists add a table row for each file metafield

			#check to see who should be able to access this document
			#if there's an embagro, print the date the doc becomes available
			#
			if (   (defined($rdfile->get_value('security'))) ne 'public'
				&& (defined($rdfile->get_value('date_embargo'))) ne '')
			{
				my $docavailable =
					$repository->make_element('div',
					class => 'rd_doc_available',);
				my $until       = $repository->make_text(' until ');
				my $dateembargo = $rdfile->render_value('date_embargo');
				my $security    = $rdfile->render_value('security');
				$docavailable->appendChild($security);
				$docavailable->appendChild($until);
				$docavailable->appendChild($dateembargo);
				$filetable->appendChild(
					$repository->render_row(
						$repository->html_phrase('document_fieldname_security'),
						$docavailable
					)
				);
			}
			else
			{

				$filetable->appendChild(
					$repository->render_row(
						$repository->html_phrase('document_fieldname_security'),
						$rdfile->render_value('security')
					)
				);
			}

 # loop through the remaining document metadata and add a row of data for each -
			my @rd_filemeta_items =
				qw(content formatdesc rev_number mime_type license);

			# get docid to use as prefix on div ids
			foreach my $rd_filemeta_item (@rd_filemeta_items)
			{
				if (   $rdfile->is_set($rd_filemeta_item)
					&& $rd_filemeta_item eq 'mime_type')
				{
					$filetable->appendChild(
						$repository->render_row(
							$repository->html_phrase(
								'file_fieldname_' . $rd_filemeta_item
							),

							#$rdfile->render_value($rd_filemeta_item_value)
							$rdfile->render_value($rd_filemeta_item)
						)
					);
				}

				elsif ($rdfile->is_set($rd_filemeta_item))
				{
					$filetable->appendChild(
						$repository->render_row(
							$repository->html_phrase(
								'document_fieldname_' . $rd_filemeta_item
							),
							$rdfile->render_value($rd_filemeta_item)
						)
					);
				}
			}

			# calculate the filesize of each file and print it
			if (defined($rdfile))
			{
				my %files         = $rdfile->files;
				my $size_in_bytes = ($files{$rdfile->get_main('filesize')});
				my $filesize = EPrints::Utils::human_filesize($size_in_bytes);

				{
					$filetable->appendChild(
						$repository->render_row(
							$repository->html_phrase('file_fieldname_filesize'),
							$repository->make_text($filesize)
						)
					);
				}
			}

			# append filetable to filemetadiv
			$filemetadiv->appendChild($filetable);

			# render filename as link element and append to left side of table
			$a->appendChild($repository->make_text($filetmp_trunc));

			# render collapsible box to house filemeta table

			my ($self) = @_;

			my %options;
			$options{session}   = $self->{session};
			$options{id}        = $doc_prefix . '_file_meta';
			$options{title}     = $a;
			$options{content}   = $filemetadiv;
			$options{collapsed} = 1;
			my $filebox = EPrints::Box::render(%options);

			# append filemetabox to file table
			$tdr->appendChild($filebox);

			# append row to table
			$rdtable->appendChild($tr);

		}

	}

# append fragment to div_right, then add div_right to the fragments hash to be sent to the dom
	$div_right->appendChild($rddocsfrag);
	$fragments{rd_sorteddocs} = $div_right;

	foreach my $key (keys %fragments)
	{
		$fragments{$key} = [$fragments{$key}, 'XHTML'];
	}

	my $page = $eprint->render_citation('rdl_summary_page', %fragments,
		flags => $flags);

	my $title = $eprint->render_citation('brief');
	my $links = $repository->xml()->create_document_fragment();
	if (!$preview)
	{
		$links->appendChild($repository->plugin('Export::Simple')
				->dataobj_to_html_header($eprint));
		$links->appendChild(
			$repository->plugin('Export::DC')->dataobj_to_html_header($eprint));
	}

	return ($page, $title, $links);
};

# update advanced search
$c->{search}->{advanced} ={
	search_fields => [
		{ meta_fields => ['documents'] },
		{ meta_fields => ['creators_name'] },
		{ meta_fields => ['title'] },
		{ meta_fields => ['abstract'] },
		{ meta_fields => ['date'] },
		{ meta_fields => ['keywords'] },
		{ meta_fields => ['subjects'] },

		#		{ meta_fields => [ 'department' ] },
		{ meta_fields => ['divisions'] },
	],
	preamble_phrase => 'cgi/advsearch:preamble',
	title_phrase => 'cgi/advsearch:adv_search',
	citation => 'result',
	page_size => 20,
	order_methods => {
		'byyear' 	 => '-date/creators_name/title',
		'byyearoldest'	 => 'date/creators_name/title',
		'byname'  	 => 'creators_name/-date/title',
		'bytitle' 	 => 'title/creators_name/-date'
	},
	default_order => 'byyear',
	show_zero_results => 1,
};

